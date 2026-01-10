-- Khanh: CURSOR PROCEDURES (Simplified)
USE HotelManagement;
GO

-- CURSOR 1: sp_send_payment_reminders
-- Find outstanding payments, count totals
CREATE OR ALTER PROCEDURE sp_send_payment_reminders
    @count INT OUTPUT,
    @outstanding DECIMAL(12,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @res_id INT, @balance DECIMAL(10,2);
    SET @count = 0; SET @outstanding = 0;
    
    -- CURSOR: Reservations with unpaid balance
    DECLARE cur CURSOR FOR
        SELECT reservation_id, (total_amount - paid_amount) AS balance
        FROM RESERVATIONS
        WHERE total_amount > paid_amount AND status NOT IN ('Cancelled','Pending');
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @res_id, @balance;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @count = @count + 1;
        SET @outstanding = @outstanding + @balance;
        FETCH NEXT FROM cur INTO @res_id, @balance;
    END
    
    CLOSE cur; DEALLOCATE cur;
    RETURN 0;
END;
GO

-- CURSOR 2: sp_generate_monthly_revenue_summary
-- Calculate revenue by room type, services, payments using cursors
CREATE OR ALTER PROCEDURE sp_generate_monthly_revenue_summary
    @year INT, @month INT,
    @output NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATE, @end DATE;
    DECLARE @type NVARCHAR(50), @revenue DECIMAL(12,2), @count INT;
    DECLARE @room_total DECIMAL(12,2) = 0, @svc_total DECIMAL(12,2) = 0;
    DECLARE @room_txt NVARCHAR(MAX) = '', @svc_txt NVARCHAR(MAX) = '';
    
    SET @start = DATEFROMPARTS(@year, @month, 1);
    SET @end = EOMONTH(@start);
    
    -- CURSOR 1: Room revenue by type
    DECLARE cur1 CURSOR FOR
        SELECT rt.type_name, SUM(r.room_charge) 
        FROM RESERVATIONS r
        JOIN ROOMS rm ON r.room_id = rm.room_id
        JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
        WHERE r.status IN ('CheckedOut','CheckedIn') AND r.check_in_date BETWEEN @start AND @end
        GROUP BY rt.type_name;
    
    OPEN cur1;
    FETCH NEXT FROM cur1 INTO @type, @revenue;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @room_txt = @room_txt + @type + ': $' + CAST(@revenue AS NVARCHAR) + CHAR(13);
        SET @room_total = @room_total + @revenue;
        FETCH NEXT FROM cur1 INTO @type, @revenue;
    END
    CLOSE cur1; DEALLOCATE cur1;
    
    -- CURSOR 2: Service revenue by category
    DECLARE cur2 CURSOR FOR
        SELECT sc.category_name, SUM(su.total_price)
        FROM SERVICES_USED su
        JOIN SERVICES s ON su.service_id = s.service_id
        JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
        WHERE su.status = 'Completed' AND CAST(su.used_date AS DATE) BETWEEN @start AND @end
        GROUP BY sc.category_name;
    
    OPEN cur2;
    FETCH NEXT FROM cur2 INTO @type, @revenue;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @svc_txt = @svc_txt + @type + ': $' + CAST(@revenue AS NVARCHAR) + CHAR(13);
        SET @svc_total = @svc_total + @revenue;
        FETCH NEXT FROM cur2 INTO @type, @revenue;
    END
    CLOSE cur2; DEALLOCATE cur2;
    
    -- Build output
    SET @output = '=== REVENUE SUMMARY ' + CAST(@month AS NVARCHAR) + '/' + CAST(@year AS NVARCHAR) + ' ===' + CHAR(13) +
        'ROOM REVENUE:' + CHAR(13) + @room_txt + 'Total: $' + CAST(@room_total AS NVARCHAR) + CHAR(13) +
        'SERVICE REVENUE:' + CHAR(13) + @svc_txt + 'Total: $' + CAST(@svc_total AS NVARCHAR) + CHAR(13) +
        'GRAND TOTAL: $' + CAST(@room_total + @svc_total AS NVARCHAR);
    
    RETURN 0;
END;
GO
