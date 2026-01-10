-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- STORED PROCEDURES (SIMPLIFIED)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- PROCEDURE 1: sp_register_customer
-- Registers new customer with validation and welcome benefits
-- =============================================
CREATE OR ALTER PROCEDURE sp_register_customer
    @first_name NVARCHAR(50),
    @last_name NVARCHAR(50),
    @email NVARCHAR(100),
    @phone NVARCHAR(20) = NULL,
    @address NVARCHAR(500) = NULL,
    @id_number NVARCHAR(50) = NULL,
    @id_type NVARCHAR(50) = NULL,
    @date_of_birth DATE = NULL,
    @nationality NVARCHAR(50) = NULL,
    @customer_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Basic validation
        IF @email IS NULL OR @email NOT LIKE '%_@__%.__%'
        BEGIN
            SET @message = 'Error: Valid email is required.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check duplicate email
        IF EXISTS (SELECT 1 FROM CUSTOMERS WHERE email = @email)
        BEGIN
            SET @message = 'Error: Email already exists.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Insert new customer
        INSERT INTO CUSTOMERS (
            first_name, last_name, email, phone, address,
            id_number, id_type, date_of_birth, nationality,
            loyalty_points, membership_tier, total_spending
        )
        VALUES (
            TRIM(@first_name), TRIM(@last_name), LOWER(TRIM(@email)), 
            @phone, @address, @id_number, @id_type, @date_of_birth, @nationality,
            100, 'Bronze', 0  -- Welcome bonus: 100 points
        );
        
        SET @customer_id = SCOPE_IDENTITY();
        
        -- Create welcome notification
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, related_id, recipient_type, recipient_id
        )
        VALUES (
            'Welcome',
            'Welcome to Our Hotel!',
            'Welcome ' + @first_name + '! You received 100 welcome bonus points.',
            'CUSTOMERS', @customer_id, 'Customer', @customer_id
        );
        
        COMMIT TRANSACTION;
        
        SET @message = 'Customer registered successfully! ID: ' + CAST(@customer_id AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @customer_id = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- PROCEDURE 2: sp_add_service_to_reservation
-- Adds service to active reservation
-- =============================================
CREATE OR ALTER PROCEDURE sp_add_service_to_reservation
    @reservation_id INT,
    @service_id INT,
    @quantity INT = 1,
    @notes NVARCHAR(500) = NULL,
    @served_by INT = NULL,
    @usage_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_status NVARCHAR(20);
    DECLARE @service_name NVARCHAR(100);
    DECLARE @unit_price DECIMAL(10,2);
    DECLARE @total_price DECIMAL(10,2);
    DECLARE @service_active BIT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get reservation and service details
        SELECT @reservation_status = status
        FROM RESERVATIONS
        WHERE reservation_id = @reservation_id;
        
        SELECT @service_name = service_name, @unit_price = price, @service_active = is_active
        FROM SERVICES
        WHERE service_id = @service_id;
        
        -- Validate
        IF @reservation_status IS NULL
        BEGIN
            SET @message = 'Error: Reservation not found.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        IF @reservation_status <> 'CheckedIn'
        BEGIN
            SET @message = 'Error: Services can only be added to checked-in reservations.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        IF @service_name IS NULL OR @service_active = 0
        BEGIN
            SET @message = 'Error: Service not available.';
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Calculate price
        SET @total_price = @unit_price * @quantity;
        
        -- Insert service usage
        INSERT INTO SERVICES_USED (
            reservation_id, service_id, quantity,
            unit_price, total_price, used_date,
            notes, served_by, status
        )
        VALUES (
            @reservation_id, @service_id, @quantity,
            @unit_price, @total_price, GETDATE(),
            @notes, @served_by, 'Completed'
        );
        
        SET @usage_id = SCOPE_IDENTITY();
        
        -- Update reservation totals
        UPDATE RESERVATIONS
        SET 
            service_charge = service_charge + @total_price,
            tax_amount = (room_charge + service_charge + @total_price - discount_amount) * 0.10,
            total_amount = room_charge + service_charge + @total_price - discount_amount + 
                          ((room_charge + service_charge + @total_price - discount_amount) * 0.10),
            updated_at = GETDATE()
        WHERE reservation_id = @reservation_id;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Service added: ' + @service_name + ' x' + CAST(@quantity AS NVARCHAR) + 
                       ' = $' + CAST(@total_price AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @usage_id = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Ninh Procedures created successfully.';
GO
