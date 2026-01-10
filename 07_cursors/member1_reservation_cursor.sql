-- =============================================
-- PHUC (Member 1): CURSORS - RESERVATION & ROOM MANAGEMENT
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: Process today's check-ins
-- Purpose: Update room status for confirmed reservations checking in today
-- =============================================
DECLARE @res_id INT;
DECLARE @room_id INT;
DECLARE @cust_name NVARCHAR(100);
DECLARE @room_number NVARCHAR(10);
DECLARE @count INT = 0;

-- Step 1: Declare cursor - get today's confirmed reservations
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

-- Step 2: Open cursor
OPEN checkin_cursor;

-- Step 3: Fetch first row
FETCH NEXT FROM checkin_cursor INTO @res_id, @room_id, @cust_name, @room_number;

-- Step 4: Loop through rows
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Update room to Reserved
    UPDATE ROOMS SET status = 'Reserved', updated_at = GETDATE()
    WHERE room_id = @room_id AND status = 'Available';
    
    SET @count = @count + 1;
    PRINT N'Reservation #' + CAST(@res_id AS NVARCHAR) + 
          N' - Room ' + @room_number + 
          N' - Guest: ' + @cust_name + N' - Ready for check-in';
    
    -- Fetch next row
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

-- Declare cursor - get reservations that should have checked in but didn't
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
    AND r.status IN ('Confirmed', 'Pending')          -- Not checked in
    AND r.actual_check_in IS NULL                     -- Never arrived
    ORDER BY r.check_in_date;

-- Open cursor
OPEN noshow_cursor;
FETCH NEXT FROM noshow_cursor INTO @res_id, @cust_id, @room_id, @cust_name, @room_number, @total, @paid;

-- Loop through each no-show
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Calculate 25% penalty
    SET @penalty = @total * 0.25;
    
    -- Update reservation to NoShow
    UPDATE RESERVATIONS SET status = 'NoShow', updated_at = GETDATE()
    WHERE reservation_id = @res_id;
    
    -- Release the room
    UPDATE ROOMS SET status = 'Available', updated_at = GETDATE()
    WHERE room_id = @room_id AND status IN ('Reserved', 'Occupied');
    
    -- Process refund minus penalty (if prepaid)
    IF @paid > 0
    BEGIN
        INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, status, notes)
        VALUES (@res_id, @cust_id, -(@paid - @penalty), 'Refund', 'Completed', 
                'No-show refund minus ' + CAST(@penalty AS NVARCHAR) + ' penalty');
    END
    
    -- Deduct loyalty points as penalty
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

-- Close and deallocate
CLOSE noshow_cursor;
DEALLOCATE noshow_cursor;

PRINT N'=== Cursor 2: Processed ' + CAST(@count AS NVARCHAR) + N' no-shows. Total penalty: $' + CAST(@total_penalty AS NVARCHAR) + N' ===';
GO
