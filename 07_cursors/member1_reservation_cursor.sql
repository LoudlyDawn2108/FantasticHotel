-- =============================================
-- PHUC (Member 1): CURSORS - RESERVATION & ROOM MANAGEMENT
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: Process today's check-ins
-- =============================================
DECLARE @res_id INT;
DECLARE @room_id INT;
DECLARE @cust_name NVARCHAR(100);
DECLARE @room_number NVARCHAR(10);
DECLARE @count INT = 0;

DECLARE checkin_cursor CURSOR FOR
    SELECT 
        r.reservation_id,
        r.room_id,
        c.first_name + ' ' + c.last_name AS cust_name,
        rm.room_number
    FROM RESERVATIONS r
    INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    INNER JOIN ROOMS rm ON r.room_id = rm.room_id
    WHERE r.check_in_date = CAST(GETDATE() AS DATE)
    AND r.status = 'Confirmed'
    ORDER BY r.reservation_id;

OPEN checkin_cursor;

FETCH NEXT FROM checkin_cursor INTO @res_id, @room_id, @cust_name, @room_number;

WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE ROOMS SET status = 'Reserved', updated_at = GETDATE()
    WHERE room_id = @room_id AND status = 'Available';
    
    SET @count = @count + 1;
    PRINT N'Reservation #' + CAST(@res_id AS NVARCHAR) + 
          N' - Room ' + @room_number + 
          N' - Guest: ' + @cust_name + N' - Ready for check-in';
    
    FETCH NEXT FROM checkin_cursor INTO @res_id, @room_id, @cust_name, @room_number;
END

-- Step 5: Close and deallocate cursor
CLOSE checkin_cursor;
DEALLOCATE checkin_cursor;

PRINT N'=== Cursor 1: Processed ' + CAST(@count AS NVARCHAR) + N' check-ins for today ===';
GO


-- =============================================
-- CURSOR 2: Process no-show reservations
-- Purpose: Mark overdue reservations as NoShow, apply penalty, release rooms
-- =============================================
DECLARE @res_id INT;
DECLARE @cust_id INT;
DECLARE @room_id INT;
DECLARE @cust_name NVARCHAR(100);
DECLARE @room_number NVARCHAR(10);
DECLARE @total DECIMAL(10,2);
DECLARE @paid DECIMAL(10,2);
DECLARE @penalty DECIMAL(10,2);
DECLARE @count INT = 0;
DECLARE @total_penalty DECIMAL(10,2) = 0;

DECLARE noshow_cursor CURSOR FOR
    SELECT 
        r.reservation_id,
        r.customer_id,
        r.room_id,
        c.first_name + ' ' + c.last_name AS cust_name,
        rm.room_number,
        r.total_amount,
        r.paid_amount
    FROM RESERVATIONS r
    INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    INNER JOIN ROOMS rm ON r.room_id = rm.room_id
    WHERE r.check_in_date < CAST(GETDATE() AS DATE)  -- Past check-in date
    AND r.status = 'Confirmed'                        -- Not checked in
    AND r.actual_check_in IS NULL                     -- Never arrived
    ORDER BY r.check_in_date;

-- Open cursor
OPEN noshow_cursor;
FETCH NEXT FROM noshow_cursor INTO @res_id, @cust_id, @room_id, @cust_name, @room_number, @total, @paid;

-- Loop through each no-show
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @penalty = @total * 0.25;
    
    UPDATE RESERVATIONS SET status = 'NoShow', updated_at = GETDATE()
    WHERE reservation_id = @res_id;
    
    UPDATE ROOMS SET status = 'Available', updated_at = GETDATE()
    WHERE room_id = @room_id AND status IN ('Reserved', 'Occupied');
    
    IF @paid > 0
    BEGIN
        INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, status, notes)
        VALUES (@res_id, @cust_id, -(@paid - @penalty), 'Refund', 'Completed', 
                'No-show refund minus ' + CAST(@penalty AS NVARCHAR) + ' penalty');
    END
    
    UPDATE CUSTOMERS SET loyalty_points = CASE WHEN loyalty_points >= 50 THEN loyalty_points - 50 ELSE 0 END
    WHERE customer_id = @cust_id;
    
    SET @count = @count + 1;
    SET @total_penalty = @total_penalty + @penalty;
    
    PRINT N'No-Show: Reservation #' + CAST(@res_id AS NVARCHAR) + 
          N' - Room ' + @room_number + 
          N' - Guest: ' + @cust_name + 
          N' - Penalty: $' + CAST(@penalty AS NVARCHAR);
    
    FETCH NEXT FROM noshow_cursor INTO @res_id, @cust_id, @room_id, @cust_name, @room_number, @total, @paid;
END

CLOSE noshow_cursor;
DEALLOCATE noshow_cursor;

PRINT N'=== Cursor 2: Processed ' + CAST(@count AS NVARCHAR) + N' no-shows. Total penalty: $' + CAST(@total_penalty AS NVARCHAR) + N' ===';
GO
