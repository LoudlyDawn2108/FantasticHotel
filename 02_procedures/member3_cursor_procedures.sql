-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- CURSOR PROCEDURES (2 CURSORS)
-- =============================================
-- Business Process: Complete Customer & Service Lifecycle
-- These cursors work with sp_register_customer, sp_add_service_to_reservation,
-- vw_customer_history, vw_popular_services, trg_customer_tier_upgrade,
-- trg_service_usage_notification, fn_get_customer_discount_rate, fn_get_customer_statistics
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: sp_process_loyalty_tier_upgrades
-- Batch processes all customers eligible for tier upgrades
-- Uses CURSOR to iterate through customers and upgrade tiers
-- Authorization: Manager+ (level 70)
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_loyalty_tier_upgrades
    @user_id INT,                           -- Required: calling user for authorization
    @upgrade_count INT OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Authorization check - Manager or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 70
    BEGIN
        SET @message = 'Access denied. Manager or higher required.';
        SET @upgrade_count = 0;
        RETURN -403;
    END
    
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @customer_email NVARCHAR(100);
    DECLARE @current_tier NVARCHAR(20);
    DECLARE @total_spending DECIMAL(15,2);
    DECLARE @loyalty_points INT;
    DECLARE @new_tier NVARCHAR(20);
    DECLARE @upgrade_benefits NVARCHAR(500);
    
    SET @upgrade_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Iterate through all active customers to check for tier upgrades
        DECLARE tier_cursor CURSOR FOR
            SELECT 
                customer_id,
                first_name + ' ' + last_name AS customer_name,
                email,
                membership_tier,
                total_spending,
                loyalty_points
            FROM CUSTOMERS
            WHERE is_active = 1
            ORDER BY total_spending DESC;
        
        OPEN tier_cursor;
        FETCH NEXT FROM tier_cursor INTO 
            @customer_id, @customer_name, @customer_email,
            @current_tier, @total_spending, @loyalty_points;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calculate what tier customer should be based on spending
            SET @new_tier = CASE 
                WHEN @total_spending >= 50000 THEN 'Platinum'
                WHEN @total_spending >= 20000 THEN 'Gold'
                WHEN @total_spending >= 5000 THEN 'Silver'
                ELSE 'Bronze'
            END;
            
            -- Only process if it's an upgrade (not downgrade)
            IF (@new_tier = 'Platinum' AND @current_tier IN ('Bronze', 'Silver', 'Gold')) OR
               (@new_tier = 'Gold' AND @current_tier IN ('Bronze', 'Silver')) OR
               (@new_tier = 'Silver' AND @current_tier = 'Bronze')
            BEGIN
                -- Determine benefits for the new tier
                SET @upgrade_benefits = CASE @new_tier
                    WHEN 'Silver' THEN '5% discount, priority check-in'
                    WHEN 'Gold' THEN '10% discount, free room upgrades, late checkout'
                    WHEN 'Platinum' THEN '15% discount, VIP lounge access, free breakfast, personal concierge'
                    ELSE ''
                END;
                
                -- Update customer tier
                UPDATE CUSTOMERS
                SET 
                    membership_tier = @new_tier,
                    updated_at = GETDATE()
                WHERE customer_id = @customer_id;
                
                -- Award bonus points for tier upgrade
                DECLARE @bonus_points INT;
                SET @bonus_points = CASE @new_tier
                    WHEN 'Silver' THEN 500
                    WHEN 'Gold' THEN 1000
                    WHEN 'Platinum' THEN 2000
                    ELSE 0
                END;
                
                UPDATE CUSTOMERS
                SET loyalty_points = loyalty_points + @bonus_points
                WHERE customer_id = @customer_id;
                
                -- Log for management (notifications removed)
                INSERT INTO AUDIT_LOGS (
                    table_name, operation, record_id, old_values, new_values, changed_by
                )
                VALUES (
                    'CUSTOMERS', 'TIER_UPGRADE', @customer_id,
                    'tier:' + @current_tier + ',spending:' + CAST(@total_spending AS NVARCHAR),
                    'tier:' + @new_tier + ',bonus_points:' + CAST(@bonus_points AS NVARCHAR),
                    'SYSTEM_BATCH'
                );
                
                SET @upgrade_count = @upgrade_count + 1;
            END
            
            FETCH NEXT FROM tier_cursor INTO 
                @customer_id, @customer_name, @customer_email,
                @current_tier, @total_spending, @loyalty_points;
        END
        
        CLOSE tier_cursor;
        DEALLOCATE tier_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Tier upgrade processing completed. ' + 
                       CAST(@upgrade_count AS NVARCHAR) + ' customers upgraded.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'tier_cursor') >= 0
        BEGIN
            CLOSE tier_cursor;
            DEALLOCATE tier_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- CURSOR 2: sp_generate_service_usage_report
-- Generates detailed service usage report for a date range
-- Uses CURSOR to compile usage by customer, service, and category
-- Authorization: Manager+ (level 70)
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_service_usage_report
    @user_id INT,                           -- Required: calling user for authorization
    @start_date DATE,
    @end_date DATE,
    @report_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Authorization check - Manager or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 70
    BEGIN
        SET @message = 'Access denied. Manager or higher required.';
        SET @report_output = NULL;
        RETURN -403;
    END
    
    DECLARE @service_id INT;
    DECLARE @service_name NVARCHAR(100);
    DECLARE @category_name NVARCHAR(100);
    DECLARE @usage_count INT;
    DECLARE @total_quantity INT;
    DECLARE @total_revenue DECIMAL(12,2);
    DECLARE @avg_price DECIMAL(10,2);
    
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @customer_tier NVARCHAR(20);
    DECLARE @customer_service_spend DECIMAL(10,2);
    DECLARE @services_used INT;
    
    DECLARE @service_summary NVARCHAR(MAX) = '';
    DECLARE @top_customers NVARCHAR(MAX) = '';
    DECLARE @grand_total DECIMAL(12,2) = 0;
    DECLARE @total_transactions INT = 0;
    
    BEGIN TRY
        -- CURSOR 1: Service usage summary
        DECLARE service_cursor CURSOR FOR
            SELECT 
                s.service_id,
                s.service_name,
                sc.category_name,
                COUNT(*) AS usage_count,
                SUM(su.quantity) AS total_quantity,
                SUM(su.total_price) AS total_revenue,
                AVG(su.unit_price) AS avg_price
            FROM SERVICES_USED su
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
            WHERE su.status = 'Completed'
            AND CAST(su.used_date AS DATE) BETWEEN @start_date AND @end_date
            GROUP BY s.service_id, s.service_name, sc.category_name
            ORDER BY SUM(su.total_price) DESC;
        
        OPEN service_cursor;
        FETCH NEXT FROM service_cursor INTO 
            @service_id, @service_name, @category_name,
            @usage_count, @total_quantity, @total_revenue, @avg_price;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @service_summary = @service_summary + CHAR(13) + CHAR(10) +
                '    [' + @category_name + '] ' + @service_name + 
                ' | Used: ' + CAST(@total_quantity AS NVARCHAR) + 'x' +
                ' | Revenue: $' + FORMAT(@total_revenue, 'N2');
            
            SET @grand_total = @grand_total + @total_revenue;
            SET @total_transactions = @total_transactions + @usage_count;
            
            FETCH NEXT FROM service_cursor INTO 
                @service_id, @service_name, @category_name,
                @usage_count, @total_quantity, @total_revenue, @avg_price;
        END
        
        CLOSE service_cursor;
        DEALLOCATE service_cursor;
        
        -- CURSOR 2: Top customers by service spending
        DECLARE customer_service_cursor CURSOR FOR
            SELECT TOP 10
                c.customer_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                c.membership_tier,
                SUM(su.total_price) AS service_spend,
                COUNT(*) AS services_used
            FROM SERVICES_USED su
            INNER JOIN RESERVATIONS r ON su.reservation_id = r.reservation_id
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            WHERE su.status = 'Completed'
            AND CAST(su.used_date AS DATE) BETWEEN @start_date AND @end_date
            GROUP BY c.customer_id, c.first_name, c.last_name, c.membership_tier
            ORDER BY SUM(su.total_price) DESC;
        
        OPEN customer_service_cursor;
        FETCH NEXT FROM customer_service_cursor INTO 
            @customer_id, @customer_name, @customer_tier,
            @customer_service_spend, @services_used;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @top_customers = @top_customers + CHAR(13) + CHAR(10) +
                '    ' + @customer_name + ' [' + @customer_tier + ']' +
                ' | Spent: $' + FORMAT(@customer_service_spend, 'N2') +
                ' | Services: ' + CAST(@services_used AS NVARCHAR);
            
            FETCH NEXT FROM customer_service_cursor INTO 
                @customer_id, @customer_name, @customer_tier,
                @customer_service_spend, @services_used;
        END
        
        CLOSE customer_service_cursor;
        DEALLOCATE customer_service_cursor;
        
        -- Build report output
        SET @report_output = 
'╔══════════════════════════════════════════════════════════════╗
║              SERVICE USAGE ANALYSIS REPORT                    ║
║   ' + FORMAT(@start_date, 'MMM dd, yyyy') + ' - ' + FORMAT(@end_date, 'MMM dd, yyyy') + '                              ║
╠══════════════════════════════════════════════════════════════╣

  SERVICE BREAKDOWN
  ─────────────────────────────────────────────────────────────' +
  @service_summary + '
  
  ─────────────────────────────────────────────────────────────
  Total Transactions: ' + CAST(@total_transactions AS NVARCHAR) + '
  Grand Total Revenue: $' + FORMAT(@grand_total, 'N2') + '

  TOP CUSTOMERS BY SERVICE SPENDING
  ─────────────────────────────────────────────────────────────' +
  @top_customers + '

╚══════════════════════════════════════════════════════════════╝';
        
        SET @message = 'Service usage report generated for ' + FORMAT(@start_date, 'MMM dd') + ' to ' + FORMAT(@end_date, 'MMM dd');
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        SET @report_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Ninh Cursor Procedures created successfully.';
GO
