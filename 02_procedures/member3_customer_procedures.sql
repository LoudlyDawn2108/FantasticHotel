-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- STORED PROCEDURES
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- PROCEDURE 1: sp_register_customer
-- Registers new customer with validation,
-- duplicate check, and welcome benefits
-- Authorization: Receptionist+ (level 50)
-- =============================================
CREATE OR ALTER PROCEDURE sp_register_customer
    @user_id INT,                           -- Required: calling user for authorization
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
    
    -- Authorization check - Receptionist or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 50
    BEGIN
        SET @message = 'Access denied. Receptionist or higher required.';
        SET @customer_id = NULL;
        RETURN -403;
    END
    
    DECLARE @welcome_points INT = 100;  -- Welcome bonus points
    DECLARE @existing_customer_id INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate required fields
        IF @first_name IS NULL OR LEN(TRIM(@first_name)) = 0
        BEGIN
            SET @message = 'Error: First name is required.';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        IF @last_name IS NULL OR LEN(TRIM(@last_name)) = 0
        BEGIN
            SET @message = 'Error: Last name is required.';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate email format (basic check)
        IF @email IS NULL OR LEN(TRIM(@email)) = 0 OR @email NOT LIKE '%_@__%.__%'
        BEGIN
            SET @message = 'Error: Valid email address is required.';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check for duplicate email
        SELECT @existing_customer_id = customer_id
        FROM CUSTOMERS
        WHERE email = @email;
        
        IF @existing_customer_id IS NOT NULL
        BEGIN
            SET @message = 'Error: A customer with this email already exists (ID: ' + CAST(@existing_customer_id AS NVARCHAR) + ').';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate ID type if ID number is provided
        IF @id_number IS NOT NULL AND @id_type IS NULL
        BEGIN
            SET @message = 'Error: ID type is required when ID number is provided.';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        IF @id_type IS NOT NULL AND @id_type NOT IN ('Passport', 'ID Card', 'Driver License')
        BEGIN
            SET @message = 'Error: Invalid ID type. Accepted values: Passport, ID Card, Driver License.';
            SET @customer_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate date of birth (must be at least 18 years old)
        IF @date_of_birth IS NOT NULL AND DATEDIFF(YEAR, @date_of_birth, GETDATE()) < 18
        BEGIN
            SET @message = 'Error: Customer must be at least 18 years old.';
            SET @customer_id = NULL;
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
            TRIM(@first_name), TRIM(@last_name), LOWER(TRIM(@email)), @phone, @address,
            @id_number, @id_type, @date_of_birth, @nationality,
            @welcome_points, 'Bronze', 0
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
            'Dear ' + @first_name + ', welcome to the Hotel Management System! ' +
            'You have been awarded ' + CAST(@welcome_points AS NVARCHAR) + ' welcome bonus points. ' +
            'Enjoy your stays with us!',
            'CUSTOMERS',
            @customer_id,
            'Customer',
            @customer_id
        );
        
        COMMIT TRANSACTION;
        
        SET @message = 'Customer registered successfully! ID: ' + CAST(@customer_id AS NVARCHAR) + 
                       '. Welcome bonus: ' + CAST(@welcome_points AS NVARCHAR) + ' points.';
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
-- Adds service to active reservation with
-- availability and balance check
-- Authorization: F&B Staff+ (level 30)
-- =============================================
CREATE OR ALTER PROCEDURE sp_add_service_to_reservation
    @user_id INT,                           -- Required: calling user for authorization
    @reservation_id INT,
    @service_id INT,
    @quantity INT = 1,
    @notes NVARCHAR(500) = NULL,
    @usage_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Authorization check - F&B Staff or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 30
    BEGIN
        SET @message = 'Access denied. F&B Staff or higher required.';
        SET @usage_id = NULL;
        RETURN -403;
    END
    
    DECLARE @reservation_status NVARCHAR(20);
    DECLARE @customer_id INT;
    DECLARE @service_name NVARCHAR(100);
    DECLARE @unit_price DECIMAL(10,2);
    DECLARE @total_price DECIMAL(10,2);
    DECLARE @service_active BIT;
    DECLARE @current_service_charge DECIMAL(10,2);
    DECLARE @new_service_charge DECIMAL(10,2);
    DECLARE @new_tax DECIMAL(10,2);
    DECLARE @new_total DECIMAL(10,2);
    DECLARE @room_charge DECIMAL(10,2);
    DECLARE @discount_amount DECIMAL(10,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get reservation details
        SELECT 
            @reservation_status = status,
            @customer_id = customer_id,
            @current_service_charge = service_charge,
            @room_charge = room_charge,
            @discount_amount = discount_amount
        FROM RESERVATIONS
        WHERE reservation_id = @reservation_id;
        
        -- Validate reservation exists
        IF @reservation_status IS NULL
        BEGIN
            SET @message = 'Error: Reservation not found.';
            SET @usage_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check reservation status (must be CheckedIn)
        IF @reservation_status <> 'CheckedIn'
        BEGIN
            SET @message = 'Error: Services can only be added to checked-in reservations. Current status: ' + @reservation_status;
            SET @usage_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Get service details
        SELECT 
            @service_name = service_name,
            @unit_price = price,
            @service_active = is_active
        FROM SERVICES
        WHERE service_id = @service_id;
        
        -- Validate service exists
        IF @service_name IS NULL
        BEGIN
            SET @message = 'Error: Service not found.';
            SET @usage_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check if service is active
        IF @service_active = 0
        BEGIN
            SET @message = 'Error: Service "' + @service_name + '" is currently unavailable.';
            SET @usage_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Validate quantity
        IF @quantity <= 0
        BEGIN
            SET @message = 'Error: Quantity must be greater than zero.';
            SET @usage_id = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Calculate total price
        SET @total_price = @unit_price * @quantity;
        
        -- Insert service usage record
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
        SET @new_service_charge = @current_service_charge + @total_price;
        SET @new_tax = (@room_charge + @new_service_charge - @discount_amount) * 0.10;
        SET @new_total = @room_charge + @new_service_charge - @discount_amount + @new_tax;
        
        UPDATE RESERVATIONS
        SET 
            service_charge = @new_service_charge,
            tax_amount = @new_tax,
            total_amount = @new_total,
            updated_at = GETDATE()
        WHERE reservation_id = @reservation_id;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Service added successfully. ' +
                       @service_name + ' x' + CAST(@quantity AS NVARCHAR) + 
                       ' = $' + CAST(@total_price AS NVARCHAR) + 
                       '. New total: $' + CAST(@new_total AS NVARCHAR);
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
