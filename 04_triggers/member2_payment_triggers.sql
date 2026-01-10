-- Khanh: TRIGGERS (Simplified)
USE HotelManagement;
GO

-- trg_payment_loyalty_update: Check tier upgrade on payment
CREATE OR ALTER TRIGGER trg_payment_loyalty_update
ON PAYMENTS AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cust_id INT, @tier NVARCHAR(20), @spending DECIMAL(15,2), @new_tier NVARCHAR(20);
    
    -- Process completed positive payments
    DECLARE cur CURSOR FOR SELECT customer_id FROM inserted WHERE amount > 0 AND status = 'Completed';
    OPEN cur;
    FETCH NEXT FROM cur INTO @cust_id;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @tier = membership_tier, @spending = total_spending FROM CUSTOMERS WHERE customer_id = @cust_id;
        SET @new_tier = dbo.fn_get_customer_tier(@spending);
        
        IF @new_tier <> @tier
            UPDATE CUSTOMERS SET membership_tier = @new_tier WHERE customer_id = @cust_id;
        
        FETCH NEXT FROM cur INTO @cust_id;
    END
    CLOSE cur; DEALLOCATE cur;
END;
GO

-- trg_payment_audit: Log payment changes
CREATE OR ALTER TRIGGER trg_payment_audit
ON PAYMENTS AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(10) = CASE 
        WHEN EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted) THEN 'UPDATE'
        WHEN EXISTS(SELECT 1 FROM inserted) THEN 'INSERT' ELSE 'DELETE' END;
    
    IF @op = 'INSERT'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, new_values, changed_by)
        SELECT 'PAYMENTS', 'INSERT', payment_id, CONCAT('amount:',amount,',method:',payment_method), SYSTEM_USER FROM inserted;
    
    IF @op = 'UPDATE'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by)
        SELECT 'PAYMENTS', 'UPDATE', i.payment_id, CONCAT('amount:',d.amount), CONCAT('amount:',i.amount), SYSTEM_USER
        FROM inserted i JOIN deleted d ON i.payment_id = d.payment_id;
    
    IF @op = 'DELETE'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, changed_by)
        SELECT 'PAYMENTS', 'DELETE', payment_id, CONCAT('amount:',amount,',cust:',customer_id), SYSTEM_USER FROM deleted;
END;
GO
