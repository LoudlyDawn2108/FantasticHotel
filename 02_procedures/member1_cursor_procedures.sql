-- Phuc: CURSOR PROCEDURES (Simplified)
USE HotelManagement;
GO

-- CURSOR 1: sp_process_daily_checkins
-- Process today's check-ins, update room status
CREATE OR ALTER PROCEDURE sp_process_daily_checkins
    @count INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @res_id INT, @room_id INT;
    SET @count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Today's confirmed reservations
        DECLARE cur CURSOR FOR
            SELECT reservation_id, room_id FROM RESERVATIONS
            WHERE check_in_date = CAST(GETDATE() AS DATE) AND status = 'Confirmed';
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @res_id, @room_id;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Update room to Reserved
            UPDATE ROOMS SET status = 'Reserved' WHERE room_id = @room_id;
            SET @count = @count + 1;
            FETCH NEXT FROM cur INTO @res_id, @room_id;
        END
        
        CLOSE cur;
        DEALLOCATE cur;
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

-- CURSOR 2: sp_process_noshow_reservations
-- Process no-shows, apply penalty, release rooms
CREATE OR ALTER PROCEDURE sp_process_noshow_reservations
    @count INT OUTPUT,
    @penalty DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @res_id INT, @cust_id INT, @room_id INT;
    DECLARE @total DECIMAL(10,2), @paid DECIMAL(10,2), @pen DECIMAL(10,2);
    SET @count = 0; SET @penalty = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Past reservations not checked in
        DECLARE cur CURSOR FOR
            SELECT reservation_id, customer_id, room_id, total_amount, paid_amount
            FROM RESERVATIONS
            WHERE check_in_date < CAST(GETDATE() AS DATE)
            AND status IN ('Confirmed','Pending') AND actual_check_in IS NULL;
        
        OPEN cur;
        FETCH NEXT FROM cur INTO @res_id, @cust_id, @room_id, @total, @paid;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @pen = @total * 0.25; -- 25% penalty
            
            -- Update to NoShow
            UPDATE RESERVATIONS SET status = 'NoShow' WHERE reservation_id = @res_id;
            
            -- Release room
            UPDATE ROOMS SET status = 'Available' WHERE room_id = @room_id;
            
            -- Refund minus penalty
            IF @paid > 0
                INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, status)
                VALUES (@res_id, @cust_id, -(@paid - @pen), 'Refund', 'Completed');
            
            -- Deduct loyalty points
            UPDATE CUSTOMERS SET loyalty_points = CASE WHEN loyalty_points >= 50 
                THEN loyalty_points - 50 ELSE 0 END WHERE customer_id = @cust_id;
            
            SET @count = @count + 1;
            SET @penalty = @penalty + @pen;
            FETCH NEXT FROM cur INTO @res_id, @cust_id, @room_id, @total, @paid;
        END
        
        CLOSE cur;
        DEALLOCATE cur;
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
