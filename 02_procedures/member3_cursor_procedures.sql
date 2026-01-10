-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- CURSOR PROCEDURES (SIMPLIFIED)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: sp_process_loyalty_tier_upgrades
-- Batch processes customers eligible for tier upgrades
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_loyalty_tier_upgrades
    @upgrade_count INT OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @current_tier NVARCHAR(20);
    DECLARE @total_spending DECIMAL(15,2);
    DECLARE @new_tier NVARCHAR(20);
    DECLARE @bonus_points INT;
    
    SET @upgrade_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Iterate through customers to check for tier upgrades
        DECLARE tier_cursor CURSOR FOR
            SELECT 
                customer_id,
                first_name + ' ' + last_name AS customer_name,
                membership_tier,
                total_spending
            FROM CUSTOMERS
            WHERE is_active = 1
            ORDER BY total_spending DESC;
        
        OPEN tier_cursor;
        FETCH NEXT FROM tier_cursor INTO @customer_id, @customer_name, @current_tier, @total_spending;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calculate new tier
            SET @new_tier = CASE 
                WHEN @total_spending >= 50000 THEN 'Platinum'
                WHEN @total_spending >= 20000 THEN 'Gold'
                WHEN @total_spending >= 5000 THEN 'Silver'
                ELSE 'Bronze'
            END;
            
            -- Check if upgrade needed
            IF (@new_tier = 'Platinum' AND @current_tier IN ('Bronze', 'Silver', 'Gold')) OR
               (@new_tier = 'Gold' AND @current_tier IN ('Bronze', 'Silver')) OR
               (@new_tier = 'Silver' AND @current_tier = 'Bronze')
            BEGIN
                -- Set bonus points
                SET @bonus_points = CASE @new_tier
                    WHEN 'Silver' THEN 500
                    WHEN 'Gold' THEN 1000
                    WHEN 'Platinum' THEN 2000
                END;
                
                -- Update customer tier and points
                UPDATE CUSTOMERS
                SET 
                    membership_tier = @new_tier,
                    loyalty_points = loyalty_points + @bonus_points,
                    updated_at = GETDATE()
                WHERE customer_id = @customer_id;
                
                -- Create notification
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type, recipient_id
                )
                VALUES (
                    'TierUpgrade',
                    'Upgraded to ' + @new_tier + ' Tier!',
                    @customer_name + ' upgraded from ' + @current_tier + ' to ' + @new_tier + 
                    '. Bonus: ' + CAST(@bonus_points AS NVARCHAR) + ' points!',
                    'CUSTOMERS', @customer_id, 'Customer', @customer_id
                );
                
                SET @upgrade_count = @upgrade_count + 1;
            END
            
            FETCH NEXT FROM tier_cursor INTO @customer_id, @customer_name, @current_tier, @total_spending;
        END
        
        CLOSE tier_cursor;
        DEALLOCATE tier_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Tier upgrade completed. ' + CAST(@upgrade_count AS NVARCHAR) + ' customers upgraded.';
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
-- Generates service usage report for date range
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_service_usage_report
    @start_date DATE,
    @end_date DATE,
    @report_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @service_name NVARCHAR(100);
    DECLARE @category_name NVARCHAR(100);
    DECLARE @total_quantity INT;
    DECLARE @total_revenue DECIMAL(12,2);
    DECLARE @service_summary NVARCHAR(MAX) = '';
    DECLARE @grand_total DECIMAL(12,2) = 0;
    
    BEGIN TRY
        -- CURSOR: Service usage summary
        DECLARE service_cursor CURSOR FOR
            SELECT 
                s.service_name,
                sc.category_name,
                SUM(su.quantity) AS total_quantity,
                SUM(su.total_price) AS total_revenue
            FROM SERVICES_USED su
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
            WHERE su.status = 'Completed'
            AND CAST(su.used_date AS DATE) BETWEEN @start_date AND @end_date
            GROUP BY s.service_name, sc.category_name
            ORDER BY SUM(su.total_price) DESC;
        
        OPEN service_cursor;
        FETCH NEXT FROM service_cursor INTO @service_name, @category_name, @total_quantity, @total_revenue;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @service_summary = @service_summary + 
                '[' + @category_name + '] ' + @service_name + 
                ' | Qty: ' + CAST(@total_quantity AS NVARCHAR) +
                ' | Revenue: $' + FORMAT(@total_revenue, 'N2') + CHAR(13) + CHAR(10);
            
            SET @grand_total = @grand_total + @total_revenue;
            
            FETCH NEXT FROM service_cursor INTO @service_name, @category_name, @total_quantity, @total_revenue;
        END
        
        CLOSE service_cursor;
        DEALLOCATE service_cursor;
        
        -- Build report
        SET @report_output = 
            '=== SERVICE USAGE REPORT ===' + CHAR(13) + CHAR(10) +
            'Period: ' + FORMAT(@start_date, 'MMM dd, yyyy') + ' - ' + FORMAT(@end_date, 'MMM dd, yyyy') + CHAR(13) + CHAR(10) +
            '----------------------------' + CHAR(13) + CHAR(10) +
            @service_summary +
            '----------------------------' + CHAR(13) + CHAR(10) +
            'Grand Total: $' + FORMAT(@grand_total, 'N2');
        
        SET @message = 'Report generated successfully.';
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
