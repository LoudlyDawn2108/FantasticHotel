-- =============================================
-- KHANH (Member 2): CURSORS - FINANCIAL & PAYMENT MANAGEMENT
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: Send Payment Reminders
-- Purpose: Find outstanding payments and simply list them
-- =============================================
DECLARE @res_id INT;
DECLARE @balance DECIMAL(10,2);
DECLARE @count INT = 0;
DECLARE @outstanding DECIMAL(12,2) = 0;

-- Step 1: Declare cursor
DECLARE payment_cursor CURSOR FOR
    SELECT reservation_id, (total_amount - paid_amount) AS balance
    FROM RESERVATIONS
    WHERE total_amount > paid_amount 
    AND status NOT IN ('Cancelled', 'Pending');

-- Step 2: Open cursor
OPEN payment_cursor;

-- Step 3: Fetch first row
FETCH NEXT FROM payment_cursor INTO @res_id, @balance;

-- Step 4: Loop
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @count = @count + 1;
    SET @outstanding = @outstanding + @balance;
    
    PRINT N'Reminder: Reservation #' + CAST(@res_id AS NVARCHAR) + 
          N' has outstanding balance: $' + CAST(@balance AS NVARCHAR);
    
    FETCH NEXT FROM payment_cursor INTO @res_id, @balance;
END

-- Step 5: Close and deallocate
CLOSE payment_cursor;
DEALLOCATE payment_cursor;

PRINT N'=== Cursor 1: Create ' + CAST(@count AS NVARCHAR) + N' reminders. Total outstanding: $' + CAST(@outstanding AS NVARCHAR) + N' ===';
GO


-- =============================================
-- CURSOR 2: Monthly Revenue Summary
-- Purpose: Calculate revenue by room type and service category
-- =============================================
DECLARE @year INT = 2023; -- Example year
DECLARE @month INT = 1;   -- Example month (January)
DECLARE @start DATE = DATEFROMPARTS(@year, @month, 1);
DECLARE @end DATE = EOMONTH(@start);

DECLARE @type_name NVARCHAR(50);
DECLARE @revenue DECIMAL(12,2);
DECLARE @room_total DECIMAL(12,2) = 0;
DECLARE @svc_total DECIMAL(12,2) = 0;

PRINT N'=== REVENUE SUMMARY FOR ' + CAST(@month AS NVARCHAR) + '/' + CAST(@year AS NVARCHAR) + N' ===';

-- Part A: Room Revenue
PRINT N'--- ROOM REVENUE ---';
DECLARE room_rev_cursor CURSOR FOR
    SELECT rt.type_name, SUM(r.room_charge) 
    FROM RESERVATIONS r
    JOIN ROOMS rm ON r.room_id = rm.room_id
    JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
    WHERE r.status IN ('CheckedOut','CheckedIn') 
    AND r.check_in_date BETWEEN @start AND @end
    GROUP BY rt.type_name;

OPEN room_rev_cursor;
FETCH NEXT FROM room_rev_cursor INTO @type_name, @revenue;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @type_name + N': $' + CAST(@revenue AS NVARCHAR);
    SET @room_total = @room_total + @revenue;
    FETCH NEXT FROM room_rev_cursor INTO @type_name, @revenue;
END

CLOSE room_rev_cursor;
DEALLOCATE room_rev_cursor;
PRINT N'Total Room Revenue: $' + CAST(@room_total AS NVARCHAR);


-- Part B: Service Revenue
PRINT N'--- SERVICE REVENUE ---';
DECLARE svc_rev_cursor CURSOR FOR
    SELECT sc.category_name, SUM(su.total_price)
    FROM SERVICES_USED su
    JOIN SERVICES s ON su.service_id = s.service_id
    JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
    WHERE su.status = 'Completed' 
    AND CAST(su.used_date AS DATE) BETWEEN @start AND @end
    GROUP BY sc.category_name;

OPEN svc_rev_cursor;
FETCH NEXT FROM svc_rev_cursor INTO @type_name, @revenue;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @type_name + N': $' + CAST(@revenue AS NVARCHAR);
    SET @svc_total = @svc_total + @revenue;
    FETCH NEXT FROM svc_rev_cursor INTO @type_name, @revenue;
END

CLOSE svc_rev_cursor;
DEALLOCATE svc_rev_cursor;
PRINT N'Total Service Revenue: $' + CAST(@svc_total AS NVARCHAR);

-- Grand Total
PRINT N'=============================================';
PRINT N'GRAND TOTAL: $' + CAST(@room_total + @svc_total AS NVARCHAR);
GO
