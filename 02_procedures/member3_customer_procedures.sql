-- Ninh: CUSTOMER PROCEDURES (Simplified)
USE HotelManagement;
GO

-- sp_register_customer: Register new customer with welcome points
CREATE OR ALTER PROCEDURE sp_register_customer
    @fname NVARCHAR(50), @lname NVARCHAR(50), @email NVARCHAR(100),
    @phone NVARCHAR(20) = NULL,
    @cust_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Check duplicate email
        IF EXISTS (SELECT 1 FROM CUSTOMERS WHERE email = @email)
        BEGIN
            ROLLBACK; RETURN -1;
        END
        
        -- Insert customer with 100 welcome points
        INSERT INTO CUSTOMERS (first_name, last_name, email, phone, 
            loyalty_points, membership_tier, total_spending)
        VALUES (TRIM(@fname), TRIM(@lname), LOWER(TRIM(@email)), @phone,
            100, 'Bronze', 0);
        
        SET @cust_id = SCOPE_IDENTITY();
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @cust_id = NULL;
        RETURN -1;
    END CATCH
END;
GO

-- sp_add_service_to_reservation: Add service, update totals
CREATE OR ALTER PROCEDURE sp_add_service_to_reservation
    @res_id INT, @svc_id INT, @qty INT = 1,
    @usage_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status NVARCHAR(20), @price DECIMAL(10,2), @total DECIMAL(10,2);
    DECLARE @svc_charge DECIMAL(10,2), @room_charge DECIMAL(10,2), @discount DECIMAL(10,2);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get reservation (must be CheckedIn)
        SELECT @status = status, @svc_charge = service_charge,
               @room_charge = room_charge, @discount = discount_amount
        FROM RESERVATIONS WHERE reservation_id = @res_id;
        
        IF @status <> 'CheckedIn' BEGIN ROLLBACK; RETURN -1; END
        
        -- Get service price
        SELECT @price = price FROM SERVICES WHERE service_id = @svc_id AND is_active = 1;
        IF @price IS NULL BEGIN ROLLBACK; RETURN -1; END
        
        SET @total = @price * @qty;
        
        -- Insert service usage
        INSERT INTO SERVICES_USED (reservation_id, service_id, quantity, unit_price, total_price, used_date, status)
        VALUES (@res_id, @svc_id, @qty, @price, @total, GETDATE(), 'Completed');
        SET @usage_id = SCOPE_IDENTITY();
        
        -- Update reservation totals
        SET @svc_charge = @svc_charge + @total;
        UPDATE RESERVATIONS SET 
            service_charge = @svc_charge,
            tax_amount = (@room_charge + @svc_charge - @discount) * 0.10,
            total_amount = @room_charge + @svc_charge - @discount + (@room_charge + @svc_charge - @discount) * 0.10
        WHERE reservation_id = @res_id;
        
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @usage_id = NULL;
        RETURN -1;
    END CATCH
END;
GO
