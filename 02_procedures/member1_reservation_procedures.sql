-- =============================================
-- Phuc: RESERVATION & ROOM MANAGEMENT
-- STORED PROCEDURES
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- PROCEDURE 1: sp_create_reservation
-- Creates a new reservation with full validation,
-- availability check, price calculation, and room status update
-- =============================================
CREATE OR ALTER PROCEDURE sp_create_reservation
    @customer_id INT,
    @room_id INT,
    @check_in_date DATE,
    @check_out_date DATE,
    @num_guests INT = 1,
    @special_requests NVARCHAR(1000) = NULL,
    @created_by INT = NULL,
    @reservation_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Declare variables
    DECLARE @room_charge DECIMAL(10,2);
    DECLARE @tax_amount DECIMAL(10,2);
    DECLARE @discount_rate DECIMAL(5,2);
    DECLARE @discount_amount DECIMAL(10,2);
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @num_nights INT;
    DECLARE @room_capacity INT;
    DECLARE @base_price DECIMAL(10,2);
    DECLARE @customer_tier NVARCHAR(20);
    DECLARE @is_available BIT;
    
    -- Start transaction
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate customer exists
        IF NOT EXISTS (SELECT 1 FROM CUSTOMERS WHERE customer_id = @customer_id AND is_active = 1)
        BEGIN
            SET @message = 'Error: Customer not found or inactive.';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate room exists
        IF NOT EXISTS (SELECT 1 FROM ROOMS WHERE room_id = @room_id AND is_active = 1)
        BEGIN
            SET @message = 'Error: Room not found or inactive.';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate dates
        IF @check_in_date >= @check_out_date
        BEGIN
            SET @message = 'Error: Check-out date must be after check-in date.';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        IF @check_in_date < CAST(GETDATE() AS DATE)
        BEGIN
            SET @message = 'Error: Check-in date cannot be in the past.';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Get room capacity and check guest count
        SELECT @room_capacity = rt.capacity, @base_price = rt.base_price
        FROM ROOMS r
        INNER JOIN ROOM_TYPES rt ON r.type_id = rt.type_id
        WHERE r.room_id = @room_id;
        
        IF @num_guests > @room_capacity
        BEGIN
            SET @message = 'Error: Number of guests exceeds room capacity (' + CAST(@room_capacity AS NVARCHAR) + ').';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check room availability using function
        SET @is_available = dbo.fn_check_room_availability(@room_id, @check_in_date, @check_out_date);
        
        IF @is_available = 0
        BEGIN
            SET @message = 'Error: Room is not available for the selected dates.';
            SET @reservation_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Calculate number of nights
        SET @num_nights = DATEDIFF(DAY, @check_in_date, @check_out_date);
        
        -- Calculate room charge using function
        SET @room_charge = dbo.fn_calculate_room_price(@room_id, @check_in_date, @check_out_date, @customer_id);
        
        -- Get customer tier for discount
        SELECT @customer_tier = membership_tier FROM CUSTOMERS WHERE customer_id = @customer_id;
        
        -- Calculate discount based on membership tier
        SET @discount_rate = dbo.fn_calculate_discount_rate(@customer_tier, @room_charge);
        SET @discount_amount = @room_charge * (@discount_rate / 100);
        
        -- Calculate tax (10%)
        SET @tax_amount = (@room_charge - @discount_amount) * 0.10;
        
        -- Calculate total
        SET @total_amount = @room_charge - @discount_amount + @tax_amount;
        
        -- Insert reservation
        INSERT INTO RESERVATIONS (
            customer_id, room_id, check_in_date, check_out_date, 
            num_guests, status, room_charge, tax_amount, 
            discount_amount, total_amount, special_requests, created_by
        )
        VALUES (
            @customer_id, @room_id, @check_in_date, @check_out_date,
            @num_guests, 'Confirmed', @room_charge, @tax_amount,
            @discount_amount, @total_amount, @special_requests, @created_by
        );
        
        SET @reservation_id = SCOPE_IDENTITY();
        
        -- Update room status to Reserved if check-in is today
        IF @check_in_date = CAST(GETDATE() AS DATE)
        BEGIN
            UPDATE ROOMS 
            SET status = 'Reserved', updated_at = GETDATE()
            WHERE room_id = @room_id;
        END
        
        COMMIT TRANSACTION;
        
        SET @message = 'Reservation created successfully. Confirmation #: ' + CAST(@reservation_id AS NVARCHAR) + 
                       '. Total: $' + CAST(@total_amount AS NVARCHAR) + 
                       ' (' + CAST(@num_nights AS NVARCHAR) + ' nights)';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @reservation_id = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- PROCEDURE 2: sp_cancel_reservation
-- Cancels a booking with refund calculation,
-- room status update, and loyalty point adjustment
-- =============================================
CREATE OR ALTER PROCEDURE sp_cancel_reservation
    @reservation_id INT,
    @cancellation_reason NVARCHAR(500),
    @cancelled_by INT = NULL,
    @refund_amount DECIMAL(10,2) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @current_status NVARCHAR(20);
    DECLARE @check_in_date DATE;
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @customer_id INT;
    DECLARE @room_id INT;
    DECLARE @days_until_checkin INT;
    DECLARE @refund_percentage DECIMAL(5,2);
    DECLARE @loyalty_points_to_deduct INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get reservation details
        SELECT 
            @current_status = status,
            @check_in_date = check_in_date,
            @paid_amount = paid_amount,
            @total_amount = total_amount,
            @customer_id = customer_id,
            @room_id = room_id
        FROM RESERVATIONS
        WHERE reservation_id = @reservation_id;
        
        -- Validate reservation exists
        IF @current_status IS NULL
        BEGIN
            SET @message = 'Error: Reservation not found.';
            SET @refund_amount = 0;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check if already cancelled or checked out
        IF @current_status IN ('Cancelled', 'CheckedOut', 'NoShow')
        BEGIN
            SET @message = 'Error: Reservation is already ' + @current_status + ' and cannot be cancelled.';
            SET @refund_amount = 0;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check if already checked in
        IF @current_status = 'CheckedIn'
        BEGIN
            SET @message = 'Error: Cannot cancel a reservation that is already checked in. Please process checkout instead.';
            SET @refund_amount = 0;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Calculate days until check-in
        SET @days_until_checkin = DATEDIFF(DAY, GETDATE(), @check_in_date);
        
        -- Determine refund percentage based on cancellation policy
        -- More than 7 days: 100% refund
        -- 3-7 days: 75% refund
        -- 1-2 days: 50% refund
        -- Same day: 25% refund
        -- After check-in date: No refund
        IF @days_until_checkin > 7
            SET @refund_percentage = 100.00;
        ELSE IF @days_until_checkin >= 3
            SET @refund_percentage = 75.00;
        ELSE IF @days_until_checkin >= 1
            SET @refund_percentage = 50.00;
        ELSE IF @days_until_checkin = 0
            SET @refund_percentage = 25.00;
        ELSE
            SET @refund_percentage = 0.00;
        
        -- Calculate refund
        SET @refund_amount = @paid_amount * (@refund_percentage / 100);
        
        -- Update reservation status
        UPDATE RESERVATIONS
        SET 
            status = 'Cancelled',
            cancellation_reason = @cancellation_reason,
            cancelled_at = GETDATE(),
            updated_at = GETDATE()
        WHERE reservation_id = @reservation_id;
        
        -- Update room status back to Available if it was Reserved
        UPDATE ROOMS
        SET status = 'Available', updated_at = GETDATE()
        WHERE room_id = @room_id AND status = 'Reserved';
        
        -- Deduct loyalty points if any were earned (10 points per $100 spent)
        SET @loyalty_points_to_deduct = FLOOR(@paid_amount / 100) * 10;
        
        IF @loyalty_points_to_deduct > 0
        BEGIN
            UPDATE CUSTOMERS
            SET 
                loyalty_points = CASE 
                    WHEN loyalty_points >= @loyalty_points_to_deduct 
                    THEN loyalty_points - @loyalty_points_to_deduct 
                    ELSE 0 
                END,
                total_spending = total_spending - @paid_amount,
                updated_at = GETDATE()
            WHERE customer_id = @customer_id;
        END
        
        -- Create refund payment record if applicable
        IF @refund_amount > 0
        BEGIN
            INSERT INTO PAYMENTS (
                reservation_id, customer_id, amount, payment_method,
                status, notes
            )
            VALUES (
                @reservation_id, @customer_id, -@refund_amount, 'Refund',
                'Completed', 'Refund for cancelled reservation'
            );
        END
        
        COMMIT TRANSACTION;
        
        SET @message = 'Reservation cancelled successfully. Refund: $' + 
                       CAST(@refund_amount AS NVARCHAR) + 
                       ' (' + CAST(@refund_percentage AS NVARCHAR) + '% of paid amount)';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @refund_amount = 0;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Phuc Procedures created successfully.';
GO
