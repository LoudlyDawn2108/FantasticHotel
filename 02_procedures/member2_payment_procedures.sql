-- =============================================
-- MEMBER 2: PAYMENT & FINANCIAL MANAGEMENT
-- STORED PROCEDURES
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- PROCEDURE 1: sp_process_payment
-- Processes payment with validation, receipt generation,
-- and loyalty points update
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_payment
    @reservation_id INT,
    @amount DECIMAL(10,2),
    @payment_method NVARCHAR(50),
    @transaction_ref NVARCHAR(100) = NULL,
    @processed_by INT = NULL,
    @payment_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @customer_id INT;
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @remaining_amount DECIMAL(10,2);
    DECLARE @new_paid_amount DECIMAL(10,2);
    DECLARE @loyalty_points_earned INT;
    DECLARE @customer_tier NVARCHAR(20);
    DECLARE @reservation_status NVARCHAR(20);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get reservation details
        SELECT 
            @customer_id = customer_id,
            @total_amount = total_amount,
            @paid_amount = paid_amount,
            @reservation_status = status
        FROM RESERVATIONS
        WHERE reservation_id = @reservation_id;
        
        -- Validate reservation exists
        IF @customer_id IS NULL
        BEGIN
            SET @message = 'Error: Reservation not found.';
            SET @payment_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check reservation status
        IF @reservation_status IN ('Cancelled', 'NoShow')
        BEGIN
            SET @message = 'Error: Cannot process payment for ' + @reservation_status + ' reservation.';
            SET @payment_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate amount
        IF @amount <= 0
        BEGIN
            SET @message = 'Error: Payment amount must be greater than zero.';
            SET @payment_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate payment method
        IF @payment_method NOT IN ('Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Payment')
        BEGIN
            SET @message = 'Error: Invalid payment method. Accepted: Cash, Credit Card, Debit Card, Bank Transfer, Mobile Payment.';
            SET @payment_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Calculate remaining balance
        SET @remaining_amount = @total_amount - @paid_amount;
        
        -- Check if trying to overpay
        IF @amount > @remaining_amount
        BEGIN
            SET @message = 'Warning: Amount exceeds remaining balance of $' + CAST(@remaining_amount AS NVARCHAR) + '. Processing partial payment.';
            SET @amount = @remaining_amount;
        END
        
        -- Generate transaction reference if not provided
        IF @transaction_ref IS NULL
            SET @transaction_ref = 'TXN-' + FORMAT(GETDATE(), 'yyyyMMdd') + '-' + RIGHT('00000' + CAST(ABS(CHECKSUM(NEWID())) % 100000 AS NVARCHAR), 5);
        
        -- Insert payment record
        INSERT INTO PAYMENTS (
            reservation_id, customer_id, amount, payment_method,
            payment_date, status, transaction_ref, processed_by
        )
        VALUES (
            @reservation_id, @customer_id, @amount, @payment_method,
            GETDATE(), 'Completed', @transaction_ref, @processed_by
        );
        
        SET @payment_id = SCOPE_IDENTITY();
        
        -- Update reservation paid amount
        SET @new_paid_amount = @paid_amount + @amount;
        
        UPDATE RESERVATIONS
        SET 
            paid_amount = @new_paid_amount,
            updated_at = GETDATE()
        WHERE reservation_id = @reservation_id;
        
        -- Calculate and add loyalty points (using function)
        SELECT @customer_tier = membership_tier FROM CUSTOMERS WHERE customer_id = @customer_id;
        SET @loyalty_points_earned = dbo.fn_calculate_loyalty_points(@amount, @customer_tier);
        
        -- Update customer loyalty points and total spending
        UPDATE CUSTOMERS
        SET 
            loyalty_points = loyalty_points + @loyalty_points_earned,
            total_spending = total_spending + @amount,
            updated_at = GETDATE()
        WHERE customer_id = @customer_id;
        
        -- Check if customer qualifies for tier upgrade
        -- (This will be handled by trigger trg_customer_tier_upgrade)
        
        COMMIT TRANSACTION;
        
        -- Build success message
        SET @message = 'Payment processed successfully. ' +
                       'Transaction: ' + @transaction_ref + '. ' +
                       'Amount: $' + CAST(@amount AS NVARCHAR) + '. ' +
                       'Points earned: ' + CAST(@loyalty_points_earned AS NVARCHAR) + '. ' +
                       CASE 
                           WHEN @new_paid_amount >= @total_amount THEN 'Balance: PAID IN FULL.'
                           ELSE 'Remaining balance: $' + CAST(@total_amount - @new_paid_amount AS NVARCHAR)
                       END;
        
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @payment_id = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- PROCEDURE 2: sp_generate_invoice
-- Creates detailed invoice with all services,
-- taxes, and discounts using cursor
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_invoice
    @reservation_id INT,
    @invoice_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @customer_email NVARCHAR(100);
    DECLARE @room_number NVARCHAR(10);
    DECLARE @room_type NVARCHAR(50);
    DECLARE @check_in DATE;
    DECLARE @check_out DATE;
    DECLARE @num_nights INT;
    DECLARE @room_charge DECIMAL(10,2);
    DECLARE @service_charge DECIMAL(10,2);
    DECLARE @tax_amount DECIMAL(10,2);
    DECLARE @discount_amount DECIMAL(10,2);
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @reservation_status NVARCHAR(20);
    
    -- Variables for service cursor
    DECLARE @service_name NVARCHAR(100);
    DECLARE @service_qty INT;
    DECLARE @service_price DECIMAL(10,2);
    DECLARE @service_total DECIMAL(10,2);
    DECLARE @service_date DATETIME;
    DECLARE @services_list NVARCHAR(MAX) = '';
    DECLARE @service_count INT = 0;
    
    BEGIN TRY
        -- Get reservation and customer details
        SELECT 
            @customer_id = r.customer_id,
            @customer_name = c.first_name + ' ' + c.last_name,
            @customer_email = c.email,
            @room_number = rm.room_number,
            @room_type = rt.type_name,
            @check_in = r.check_in_date,
            @check_out = r.check_out_date,
            @room_charge = r.room_charge,
            @service_charge = r.service_charge,
            @tax_amount = r.tax_amount,
            @discount_amount = r.discount_amount,
            @total_amount = r.total_amount,
            @paid_amount = r.paid_amount,
            @reservation_status = r.status
        FROM RESERVATIONS r
        INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
        INNER JOIN ROOMS rm ON r.room_id = rm.room_id
        INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
        WHERE r.reservation_id = @reservation_id;
        
        -- Validate reservation exists
        IF @customer_id IS NULL
        BEGIN
            SET @message = 'Error: Reservation not found.';
            SET @invoice_output = NULL;
            RETURN -1;
        END
        
        -- Calculate number of nights
        SET @num_nights = DATEDIFF(DAY, @check_in, @check_out);
        
        -- Use cursor to iterate through services
        DECLARE service_cursor CURSOR FOR
            SELECT 
                s.service_name,
                su.quantity,
                su.unit_price,
                su.total_price,
                su.used_date
            FROM SERVICES_USED su
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            WHERE su.reservation_id = @reservation_id
            AND su.status = 'Completed'
            ORDER BY su.used_date;
        
        OPEN service_cursor;
        FETCH NEXT FROM service_cursor INTO @service_name, @service_qty, @service_price, @service_total, @service_date;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @service_count = @service_count + 1;
            SET @services_list = @services_list + 
                CHAR(13) + CHAR(10) + '    ' + 
                CAST(@service_count AS NVARCHAR) + '. ' +
                @service_name + ' x' + CAST(@service_qty AS NVARCHAR) + 
                ' @ $' + CAST(@service_price AS NVARCHAR) + 
                ' = $' + CAST(@service_total AS NVARCHAR) +
                ' (' + FORMAT(@service_date, 'MMM dd') + ')';
            
            FETCH NEXT FROM service_cursor INTO @service_name, @service_qty, @service_price, @service_total, @service_date;
        END
        
        CLOSE service_cursor;
        DEALLOCATE service_cursor;
        
        -- Build invoice output
        SET @invoice_output = 
'╔══════════════════════════════════════════════════════════════╗
║                    HOTEL MANAGEMENT SYSTEM                    ║
║                         TAX INVOICE                           ║
╠══════════════════════════════════════════════════════════════╣
  Invoice Date: ' + FORMAT(GETDATE(), 'MMMM dd, yyyy HH:mm') + '
  Invoice No: INV-' + RIGHT('000000' + CAST(@reservation_id AS NVARCHAR), 6) + '
  
  GUEST INFORMATION
  ─────────────────────────────────────────────────────────────
  Name: ' + @customer_name + '
  Email: ' + @customer_email + '
  
  RESERVATION DETAILS
  ─────────────────────────────────────────────────────────────
  Confirmation #: ' + CAST(@reservation_id AS NVARCHAR) + '
  Room: ' + @room_number + ' (' + @room_type + ')
  Check-in: ' + FORMAT(@check_in, 'MMMM dd, yyyy') + '
  Check-out: ' + FORMAT(@check_out, 'MMMM dd, yyyy') + '
  Duration: ' + CAST(@num_nights AS NVARCHAR) + ' night(s)
  Status: ' + @reservation_status + '
  
  CHARGES
  ─────────────────────────────────────────────────────────────
  Room Accommodation (' + CAST(@num_nights AS NVARCHAR) + ' nights)    $' + FORMAT(@room_charge, 'N2') + '
  
  Additional Services:' + 
  CASE WHEN @service_count > 0 THEN @services_list ELSE CHAR(13) + CHAR(10) + '    (No additional services)' END + '
  
  ─────────────────────────────────────────────────────────────
  Subtotal:                              $' + FORMAT(@room_charge + @service_charge, 'N2') + '
  Discount:                             -$' + FORMAT(@discount_amount, 'N2') + '
  Tax (10%):                             $' + FORMAT(@tax_amount, 'N2') + '
  ─────────────────────────────────────────────────────────────
  TOTAL:                                 $' + FORMAT(@total_amount, 'N2') + '
  Amount Paid:                           $' + FORMAT(@paid_amount, 'N2') + '
  BALANCE DUE:                           $' + FORMAT(@total_amount - @paid_amount, 'N2') + '
  
╚══════════════════════════════════════════════════════════════╝
  Thank you for staying with us!
  We look forward to welcoming you again.
';
        
        SET @message = 'Invoice generated successfully for reservation #' + CAST(@reservation_id AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        SET @invoice_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        
        IF CURSOR_STATUS('local', 'service_cursor') >= 0
        BEGIN
            CLOSE service_cursor;
            DEALLOCATE service_cursor;
        END
        
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Member 2 Procedures created successfully.';
GO
