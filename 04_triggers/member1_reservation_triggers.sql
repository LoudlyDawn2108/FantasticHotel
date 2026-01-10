-- =============================================
-- Phuc: RESERVATION & ROOM MANAGEMENT
-- TRIGGERS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_reservation_status_change
-- Updates room status when reservation status changes
-- (check-in, check-out, cancellation)
-- =============================================
CREATE OR ALTER TRIGGER trg_reservation_status_change
ON RESERVATIONS
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Only proceed if status column was updated
    IF NOT UPDATE(status)
        RETURN;
    
    DECLARE @reservation_id INT;
    DECLARE @room_id INT;
    DECLARE @old_status NVARCHAR(20);
    DECLARE @new_status NVARCHAR(20);
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    
    -- Use cursor to handle multiple row updates
    DECLARE status_cursor CURSOR FOR
        SELECT 
            i.reservation_id,
            i.room_id,
            d.status AS old_status,
            i.status AS new_status,
            i.customer_id
        FROM inserted i
        INNER JOIN deleted d ON i.reservation_id = d.reservation_id
        WHERE i.status <> d.status;
    
    OPEN status_cursor;
    FETCH NEXT FROM status_cursor INTO @reservation_id, @room_id, @old_status, @new_status, @customer_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get customer name
        SELECT @customer_name = first_name + ' ' + last_name 
        FROM CUSTOMERS WHERE customer_id = @customer_id;
        
        -- Handle different status transitions
        IF @new_status = 'CheckedIn'
        BEGIN
            -- Update room to Occupied
            UPDATE ROOMS 
            SET status = 'Occupied', updated_at = GETDATE()
            WHERE room_id = @room_id;
            
            -- Update actual check-in time if not already set
            UPDATE RESERVATIONS
            SET actual_check_in = GETDATE()
            WHERE reservation_id = @reservation_id AND actual_check_in IS NULL;
        END
        
        ELSE IF @new_status = 'CheckedOut'
        BEGIN
            -- Update room to Cleaning (needs to be cleaned before next guest)
            UPDATE ROOMS 
            SET status = 'Cleaning', updated_at = GETDATE()
            WHERE room_id = @room_id;
            
            -- Update actual check-out time if not already set
            UPDATE RESERVATIONS
            SET actual_check_out = GETDATE()
            WHERE reservation_id = @reservation_id AND actual_check_out IS NULL;
        END
        
        ELSE IF @new_status = 'Cancelled'
        BEGIN
            -- Update room back to Available only if it was Reserved
            UPDATE ROOMS 
            SET status = 'Available', updated_at = GETDATE()
            WHERE room_id = @room_id AND status = 'Reserved';
        END
        
        ELSE IF @new_status = 'Confirmed' AND @old_status = 'Pending'
        BEGIN
            -- Check if check-in date is today, set room to Reserved
            IF EXISTS (SELECT 1 FROM RESERVATIONS WHERE reservation_id = @reservation_id AND check_in_date = CAST(GETDATE() AS DATE))
            BEGIN
                UPDATE ROOMS 
                SET status = 'Reserved', updated_at = GETDATE()
                WHERE room_id = @room_id AND status = 'Available';
            END
        END
        
        ELSE IF @new_status = 'NoShow'
        BEGIN
            -- Update room back to Available
            UPDATE ROOMS 
            SET status = 'Available', updated_at = GETDATE()
            WHERE room_id = @room_id AND status = 'Reserved';
        END
        
        FETCH NEXT FROM status_cursor INTO @reservation_id, @room_id, @old_status, @new_status, @customer_id;
    END
    
    CLOSE status_cursor;
    DEALLOCATE status_cursor;
END;
GO

-- =============================================
-- TRIGGER 2: trg_reservation_audit
-- Logs all reservation changes to AUDIT_LOGS table
-- for tracking and compliance
-- =============================================
CREATE OR ALTER TRIGGER trg_reservation_audit
ON RESERVATIONS
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @operation NVARCHAR(20);
    DECLARE @user_name NVARCHAR(100);
    
    -- Get current user
    SET @user_name = SYSTEM_USER;
    
    -- Determine operation type
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @operation = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @operation = 'INSERT';
    ELSE
        SET @operation = 'DELETE';
    
    -- Log INSERT operations
    IF @operation = 'INSERT'
    BEGIN
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by, application)
        SELECT 
            'RESERVATIONS',
            'INSERT',
            i.reservation_id,
            NULL,
            CONCAT(
                'customer_id:', i.customer_id, 
                ',room_id:', i.room_id,
                ',check_in:', CONVERT(NVARCHAR, i.check_in_date, 120),
                ',check_out:', CONVERT(NVARCHAR, i.check_out_date, 120),
                ',status:', i.status,
                ',total:', i.total_amount
            ),
            @user_name,
            APP_NAME()
        FROM inserted i;
    END
    
    -- Log UPDATE operations
    IF @operation = 'UPDATE'
    BEGIN
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by, application)
        SELECT 
            'RESERVATIONS',
            'UPDATE',
            i.reservation_id,
            CONCAT(
                'status:', d.status,
                ',total:', d.total_amount,
                ',paid:', d.paid_amount,
                ',service_charge:', d.service_charge
            ),
            CONCAT(
                'status:', i.status,
                ',total:', i.total_amount,
                ',paid:', i.paid_amount,
                ',service_charge:', i.service_charge
            ),
            @user_name,
            APP_NAME()
        FROM inserted i
        INNER JOIN deleted d ON i.reservation_id = d.reservation_id;
    END
    
    -- Log DELETE operations
    IF @operation = 'DELETE'
    BEGIN
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by, application)
        SELECT 
            'RESERVATIONS',
            'DELETE',
            d.reservation_id,
            CONCAT(
                'customer_id:', d.customer_id, 
                ',room_id:', d.room_id,
                ',check_in:', CONVERT(NVARCHAR, d.check_in_date, 120),
                ',check_out:', CONVERT(NVARCHAR, d.check_out_date, 120),
                ',status:', d.status,
                ',total:', d.total_amount
            ),
            NULL,
            @user_name,
            APP_NAME()
        FROM deleted d;
    END
END;
GO

PRINT 'Phuc Triggers created successfully.';
GO
