-- Ninh: CURSOR PROCEDURES (Simplified)
USE HotelManagement;
GO

-- CURSOR 1: sp_process_loyalty_tier_upgrades
-- Batch process tier upgrades based on spending
CREATE OR ALTER PROCEDURE sp_process_loyalty_tier_upgrades
    @count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cust_id INT, @tier NVARCHAR(20), @spending DECIMAL(15,2), @new_tier NVARCHAR(20);
    SET @count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: All active customers
        DECLARE cur CURSOR FOR
            SELECT customer_id, membership_tier, total_spending FROM CUSTOMERS WHERE is_active = 1;
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @cust_id, @tier, @spending;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Determine tier: 50k=Platinum, 20k=Gold, 5k=Silver
            SET @new_tier = CASE 
                WHEN @spending >= 50000 THEN 'Platinum'
                WHEN @spending >= 20000 THEN 'Gold'
                WHEN @spending >= 5000 THEN 'Silver' ELSE 'Bronze' END;
            
            -- Only upgrade (not downgrade)
            IF (@new_tier = 'Platinum' AND @tier IN ('Bronze','Silver','Gold')) OR
               (@new_tier = 'Gold' AND @tier IN ('Bronze','Silver')) OR
               (@new_tier = 'Silver' AND @tier = 'Bronze')
            BEGIN
                UPDATE CUSTOMERS SET membership_tier = @new_tier,
                    loyalty_points = loyalty_points + CASE @new_tier 
                        WHEN 'Platinum' THEN 2000 WHEN 'Gold' THEN 1000 ELSE 500 END
                WHERE customer_id = @cust_id;
                SET @count = @count + 1;
            END
            
            FETCH NEXT FROM cur INTO @cust_id, @tier, @spending;
        END
        
        CLOSE cur; DEALLOCATE cur;
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF CURSOR_STATUS('local','cur') >= 0 BEGIN CLOSE cur; DEALLOCATE cur; END
        RETURN -1;
    END CATCH
END;
GO

-- CURSOR 2: sp_generate_service_usage_report
-- Generate service usage summary using cursor
CREATE OR ALTER PROCEDURE sp_generate_service_usage_report
    @start DATE, @end DATE,
    @output NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @svc NVARCHAR(100), @cat NVARCHAR(100), @qty INT, @rev DECIMAL(12,2);
    DECLARE @txt NVARCHAR(MAX) = '', @total DECIMAL(12,2) = 0;
    
    -- CURSOR: Service usage summary
    DECLARE cur CURSOR FOR
        SELECT s.service_name, sc.category_name, SUM(su.quantity), SUM(su.total_price)
        FROM SERVICES_USED su
        JOIN SERVICES s ON su.service_id = s.service_id
        JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
        WHERE su.status = 'Completed' AND CAST(su.used_date AS DATE) BETWEEN @start AND @end
        GROUP BY s.service_name, sc.category_name
        ORDER BY SUM(su.total_price) DESC;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @svc, @cat, @qty, @rev;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @txt = @txt + '[' + @cat + '] ' + @svc + ' x' + CAST(@qty AS NVARCHAR) + 
            ' = $' + CAST(@rev AS NVARCHAR) + CHAR(13);
        SET @total = @total + @rev;
        FETCH NEXT FROM cur INTO @svc, @cat, @qty, @rev;
    END
    
    CLOSE cur; DEALLOCATE cur;
    
    SET @output = '=== SERVICE USAGE REPORT ===' + CHAR(13) +
        'Period: ' + CAST(@start AS NVARCHAR) + ' to ' + CAST(@end AS NVARCHAR) + CHAR(13) +
        @txt + 'TOTAL: $' + CAST(@total AS NVARCHAR);
    
    RETURN 0;
END;
GO
