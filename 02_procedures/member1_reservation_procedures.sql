-- Phuc: RESERVATION PROCEDURES (Simplified)
USE HotelManagement;
GO

-- sp_create_reservation: Create booking with price calculation
CREATE OR ALTER PROCEDURE sp_create_reservation
    @cust_id INT, @room_id INT,
    @checkin DATE, @checkout DATE,
    @guests INT = 1,
    @res_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @price DECIMAL(10,2), @tax DECIMAL(10,2), @total DECIMAL(10,2);
    DECLARE @nights INT, @tier NVARCHAR(20), @discount DECIMAL(5,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate room available
        IF dbo.fn_check_room_availability(@room_id, @checkin, @checkout) = 0
        BEGIN
            ROLLBACK; RETURN -1;
        END
        
        -- Calculate price
        SET @nights = DATEDIFF(DAY, @checkin, @checkout);
        SELECT @price = rt.base_price * @nights
        FROM ROOMS r JOIN ROOM_TYPES rt ON r.type_id = rt.type_id
        WHERE r.room_id = @room_id;
        
        -- Get discount by tier
        SELECT @tier = membership_tier FROM CUSTOMERS WHERE customer_id = @cust_id;
        SET @discount = CASE @tier 
            WHEN 'Platinum' THEN 0.15 WHEN 'Gold' THEN 0.10 
            WHEN 'Silver' THEN 0.05 ELSE 0 END;
        
        SET @tax = @price * (1 - @discount) * 0.10;
        SET @total = @price * (1 - @discount) + @tax;
        
        -- Insert reservation
        INSERT INTO RESERVATIONS (customer_id, room_id, check_in_date, check_out_date,
            num_guests, status, room_charge, tax_amount, discount_amount, total_amount)
        VALUES (@cust_id, @room_id, @checkin, @checkout,
            @guests, 'Confirmed', @price, @tax, @price * @discount, @total);
        
        SET @res_id = SCOPE_IDENTITY();
        
        -- Update room if checkin today
        IF @checkin = CAST(GETDATE() AS DATE)
            UPDATE ROOMS SET status = 'Reserved' WHERE room_id = @room_id;
        
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RETURN -1;
    END CATCH
END;
GO

-- sp_cancel_reservation: Cancel with refund calculation
CREATE OR ALTER PROCEDURE sp_cancel_reservation
    @res_id INT,
    @reason NVARCHAR(500),
    @refund DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status NVARCHAR(20), @checkin DATE, @paid DECIMAL(10,2);
    DECLARE @room_id INT, @cust_id INT, @days INT, @pct DECIMAL(5,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        SELECT @status = status, @checkin = check_in_date, @paid = paid_amount,
               @room_id = room_id, @cust_id = customer_id
        FROM RESERVATIONS WHERE reservation_id = @res_id;
        
        IF @status IN ('Cancelled','CheckedOut','CheckedIn')
        BEGIN
            SET @refund = 0; ROLLBACK; RETURN -1;
        END
        
        -- Refund policy: >7days=100%, 3-7=75%, 1-2=50%, 0=25%
        SET @days = DATEDIFF(DAY, GETDATE(), @checkin);
        SET @pct = CASE 
            WHEN @days > 7 THEN 1.0 WHEN @days >= 3 THEN 0.75
            WHEN @days >= 1 THEN 0.5 WHEN @days = 0 THEN 0.25 ELSE 0 END;
        SET @refund = @paid * @pct;
        
        -- Update reservation
        UPDATE RESERVATIONS SET status = 'Cancelled', cancellation_reason = @reason,
            cancelled_at = GETDATE() WHERE reservation_id = @res_id;
        
        -- Release room
        UPDATE ROOMS SET status = 'Available' WHERE room_id = @room_id AND status = 'Reserved';
        
        -- Refund payment
        IF @refund > 0
            INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, status)
            VALUES (@res_id, @cust_id, -@refund, 'Refund', 'Completed');
        
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @refund = 0;
        RETURN -1;
    END CATCH
END;
GO
