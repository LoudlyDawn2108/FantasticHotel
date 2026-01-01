-- =============================================
-- MEMBER 1: RESERVATION & ROOM MANAGEMENT
-- CURSOR PROCEDURES (2 CURSORS)
-- =============================================
-- Business Process: Complete Reservation Lifecycle
-- These cursors work with sp_create_reservation, sp_cancel_reservation,
-- vw_room_availability, vw_occupancy_statistics, trg_reservation_status_change,
-- trg_reservation_audit, fn_calculate_room_price, fn_check_room_availability
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: sp_process_daily_checkins
-- Processes all reservations scheduled for check-in today
-- Updates room status to 'Reserved' and sends notifications
-- Uses CURSOR to iterate through today's check-ins
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_daily_checkins
    @processed_count INT OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @check_in_date DATE;
    DECLARE @check_out_date DATE;
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @current_status NVARCHAR(20);
    
    SET @processed_count = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Iterate through all confirmed reservations for today
        DECLARE checkin_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                r.customer_id,
                r.room_id,
                rm.room_number,
                c.first_name + ' ' + c.last_name AS customer_name,
                r.check_in_date,
                r.check_out_date,
                r.total_amount,
                r.status
            FROM RESERVATIONS r
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            WHERE r.check_in_date = CAST(GETDATE() AS DATE)
            AND r.status = 'Confirmed'
            ORDER BY r.reservation_id;
        
        OPEN checkin_cursor;
        FETCH NEXT FROM checkin_cursor INTO 
            @reservation_id, @customer_id, @room_id, @room_number,
            @customer_name, @check_in_date, @check_out_date, @total_amount, @current_status;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Update room status to Reserved
            UPDATE ROOMS
            SET status = 'Reserved', updated_at = GETDATE()
            WHERE room_id = @room_id AND status = 'Available';
            
            -- Create notification for front desk
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'DailyCheckIn',
                'Expected Arrival Today',
                'Guest: ' + @customer_name + ' | Room: ' + @room_number + 
                ' | Checkout: ' + FORMAT(@check_out_date, 'MMM dd') +
                ' | Total: $' + CAST(@total_amount AS NVARCHAR),
                'RESERVATIONS',
                @reservation_id,
                'Front Desk'
            );
            
            SET @processed_count = @processed_count + 1;
            
            FETCH NEXT FROM checkin_cursor INTO 
                @reservation_id, @customer_id, @room_id, @room_number,
                @customer_name, @check_in_date, @check_out_date, @total_amount, @current_status;
        END
        
        CLOSE checkin_cursor;
        DEALLOCATE checkin_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Daily check-in processing completed. ' + 
                       CAST(@processed_count AS NVARCHAR) + ' reservations prepared for today.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'checkin_cursor') >= 0
        BEGIN
            CLOSE checkin_cursor;
            DEALLOCATE checkin_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- CURSOR 2: sp_process_noshow_reservations
-- Processes reservations that are no-shows (didn't check in by end of day)
-- Updates status to 'NoShow', releases rooms, applies penalties
-- Uses CURSOR to iterate through no-show reservations
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_noshow_reservations
    @processed_count INT OUTPUT,
    @total_penalty DECIMAL(10,2) OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @customer_email NVARCHAR(100);
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @penalty_amount DECIMAL(10,2);
    
    SET @processed_count = 0;
    SET @total_penalty = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Iterate through reservations that should have checked in yesterday but didn't
        DECLARE noshow_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                r.customer_id,
                r.room_id,
                rm.room_number,
                c.first_name + ' ' + c.last_name AS customer_name,
                c.email AS customer_email,
                r.total_amount,
                r.paid_amount
            FROM RESERVATIONS r
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            WHERE r.check_in_date < CAST(GETDATE() AS DATE)  -- Check-in date was in the past
            AND r.status IN ('Confirmed', 'Pending')          -- Still not checked in
            AND r.actual_check_in IS NULL                     -- Never actually checked in
            ORDER BY r.check_in_date;
        
        OPEN noshow_cursor;
        FETCH NEXT FROM noshow_cursor INTO 
            @reservation_id, @customer_id, @room_id, @room_number,
            @customer_name, @customer_email, @total_amount, @paid_amount;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calculate penalty (first night charge, typically)
            SET @penalty_amount = @total_amount * 0.25;  -- 25% penalty
            
            -- Update reservation to NoShow
            UPDATE RESERVATIONS
            SET 
                status = 'NoShow',
                updated_at = GETDATE()
            WHERE reservation_id = @reservation_id;
            
            -- Release the room
            UPDATE ROOMS
            SET status = 'Available', updated_at = GETDATE()
            WHERE room_id = @room_id AND status IN ('Reserved', 'Occupied');
            
            -- Record penalty in payments (if prepaid amount exists)
            IF @paid_amount > 0
            BEGIN
                INSERT INTO PAYMENTS (
                    reservation_id, customer_id, amount, payment_method,
                    status, notes
                )
                VALUES (
                    @reservation_id, @customer_id, -(@paid_amount - @penalty_amount), 'Refund',
                    'Completed', 'Partial refund for no-show. Penalty: $' + CAST(@penalty_amount AS NVARCHAR)
                );
            END
            
            -- Deduct loyalty points (penalty)
            UPDATE CUSTOMERS
            SET 
                loyalty_points = CASE 
                    WHEN loyalty_points >= 50 THEN loyalty_points - 50 
                    ELSE 0 
                END,
                updated_at = GETDATE()
            WHERE customer_id = @customer_id;
            
            -- Create notification
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'NoShow',
                'No-Show Processed',
                'Reservation #' + CAST(@reservation_id AS NVARCHAR) + 
                ' | Guest: ' + @customer_name + 
                ' | Room ' + @room_number + ' released. Penalty: $' + CAST(@penalty_amount AS NVARCHAR),
                'RESERVATIONS',
                @reservation_id,
                'Front Desk'
            );
            
            SET @processed_count = @processed_count + 1;
            SET @total_penalty = @total_penalty + @penalty_amount;
            
            FETCH NEXT FROM noshow_cursor INTO 
                @reservation_id, @customer_id, @room_id, @room_number,
                @customer_name, @customer_email, @total_amount, @paid_amount;
        END
        
        CLOSE noshow_cursor;
        DEALLOCATE noshow_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'No-show processing completed. ' + 
                       CAST(@processed_count AS NVARCHAR) + ' no-shows processed. ' +
                       'Total penalties collected: $' + CAST(@total_penalty AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'noshow_cursor') >= 0
        BEGIN
            CLOSE noshow_cursor;
            DEALLOCATE noshow_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Member 1 Cursor Procedures created successfully.';
GO
