-- =============================================
-- MEMBER 2: PAYMENT & FINANCIAL MANAGEMENT
-- TRIGGERS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_payment_loyalty_update
-- Automatically updates customer loyalty points
-- and checks for tier upgrade on payment completion
-- =============================================
CREATE OR ALTER TRIGGER trg_payment_loyalty_update
ON PAYMENTS
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @payment_id INT;
    DECLARE @customer_id INT;
    DECLARE @amount DECIMAL(10,2);
    DECLARE @status NVARCHAR(20);
    DECLARE @customer_tier NVARCHAR(20);
    DECLARE @new_total_spending DECIMAL(15,2);
    DECLARE @new_tier NVARCHAR(20);
    
    -- Process each inserted payment
    DECLARE payment_cursor CURSOR FOR
        SELECT payment_id, customer_id, amount, status
        FROM inserted
        WHERE amount > 0;  -- Only positive payments earn points
    
    OPEN payment_cursor;
    FETCH NEXT FROM payment_cursor INTO @payment_id, @customer_id, @amount, @status;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Only process completed payments
        IF @status = 'Completed'
        BEGIN
            -- Get current customer tier
            SELECT @customer_tier = membership_tier
            FROM CUSTOMERS
            WHERE customer_id = @customer_id;
            
            -- Points are already added by sp_process_payment procedure
            -- This trigger handles tier upgrade notifications
            
            -- Get new total spending
            SELECT @new_total_spending = total_spending
            FROM CUSTOMERS
            WHERE customer_id = @customer_id;
            
            -- Determine if customer qualifies for upgrade
            SET @new_tier = dbo.fn_get_customer_tier(@new_total_spending);
            
            -- If tier changed, create notification
            IF @new_tier <> @customer_tier
            BEGIN
                -- Update customer tier
                UPDATE CUSTOMERS
                SET membership_tier = @new_tier, updated_at = GETDATE()
                WHERE customer_id = @customer_id;
                
                -- Create congratulatory notification
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message, 
                    related_table, related_id, recipient_type, recipient_id
                )
                VALUES (
                    'TierUpgrade',
                    'Congratulations! Membership Upgraded',
                    'Your membership has been upgraded from ' + @customer_tier + 
                    ' to ' + @new_tier + '! Enjoy enhanced benefits and discounts.',
                    'CUSTOMERS',
                    @customer_id,
                    'Customer',
                    @customer_id
                );
                
                -- Also notify front desk
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message, 
                    related_table, related_id, recipient_type
                )
                VALUES (
                    'TierUpgrade',
                    'Customer Tier Upgrade',
                    'Customer #' + CAST(@customer_id AS NVARCHAR) + 
                    ' has been upgraded to ' + @new_tier + ' tier.',
                    'CUSTOMERS',
                    @customer_id,
                    'Front Desk'
                );
            END
        END
        
        FETCH NEXT FROM payment_cursor INTO @payment_id, @customer_id, @amount, @status;
    END
    
    CLOSE payment_cursor;
    DEALLOCATE payment_cursor;
END;
GO

-- =============================================
-- TRIGGER 2: trg_payment_audit
-- Logs all payment transactions to AUDIT_LOGS
-- for financial tracking and compliance
-- =============================================
CREATE OR ALTER TRIGGER trg_payment_audit
ON PAYMENTS
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
            'PAYMENTS',
            'INSERT',
            i.payment_id,
            NULL,
            CONCAT(
                'reservation_id:', i.reservation_id,
                ',customer_id:', i.customer_id,
                ',amount:', i.amount,
                ',method:', i.payment_method,
                ',status:', i.status,
                ',ref:', ISNULL(i.transaction_ref, 'N/A'),
                ',date:', CONVERT(NVARCHAR, i.payment_date, 120)
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
            'PAYMENTS',
            'UPDATE',
            i.payment_id,
            CONCAT(
                'amount:', d.amount,
                ',status:', d.status
            ),
            CONCAT(
                'amount:', i.amount,
                ',status:', i.status
            ),
            @user_name,
            APP_NAME()
        FROM inserted i
        INNER JOIN deleted d ON i.payment_id = d.payment_id;
    END
    
    -- Log DELETE operations (Important for financial records)
    IF @operation = 'DELETE'
    BEGIN
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by, application)
        SELECT 
            'PAYMENTS',
            'DELETE',
            d.payment_id,
            CONCAT(
                'reservation_id:', d.reservation_id,
                ',customer_id:', d.customer_id,
                ',amount:', d.amount,
                ',method:', d.payment_method,
                ',status:', d.status,
                ',ref:', ISNULL(d.transaction_ref, 'N/A')
            ),
            NULL,
            @user_name,
            APP_NAME()
        FROM deleted d;
        
        -- Create critical notification for payment deletion
        INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, recipient_type)
        SELECT 
            'SecurityAlert',
            'Payment Record Deleted',
            'Payment #' + CAST(d.payment_id AS NVARCHAR) + 
            ' for $' + CAST(d.amount AS NVARCHAR) + 
            ' was deleted by ' + @user_name,
            'PAYMENTS',
            'Management'
        FROM deleted d;
    END
END;
GO

PRINT 'Member 2 Triggers created successfully.';
GO
