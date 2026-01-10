-- Ninh: TRIGGERS (Simplified)
USE HotelManagement;
GO

-- trg_customer_tier_upgrade: Auto-upgrade tier based on spending
CREATE OR ALTER TRIGGER trg_customer_tier_upgrade
ON CUSTOMERS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(total_spending) RETURN;
    
    DECLARE @cust_id INT, @spending DECIMAL(15,2), @old_tier NVARCHAR(20), @new_tier NVARCHAR(20);
    
    DECLARE cur CURSOR FOR
        SELECT i.customer_id, i.total_spending, d.membership_tier 
        FROM inserted i JOIN deleted d ON i.customer_id = d.customer_id
        WHERE i.total_spending <> d.total_spending;
    
    OPEN cur;
    FETCH NEXT FROM cur INTO @cust_id, @spending, @old_tier;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @new_tier = CASE 
            WHEN @spending >= 50000 THEN 'Platinum'
            WHEN @spending >= 20000 THEN 'Gold'
            WHEN @spending >= 5000 THEN 'Silver' ELSE 'Bronze' END;
        
        -- Only upgrade, never downgrade
        IF (@new_tier = 'Platinum' AND @old_tier IN ('Bronze','Silver','Gold')) OR
           (@new_tier = 'Gold' AND @old_tier IN ('Bronze','Silver')) OR
           (@new_tier = 'Silver' AND @old_tier = 'Bronze')
            UPDATE CUSTOMERS SET membership_tier = @new_tier WHERE customer_id = @cust_id;
        
        FETCH NEXT FROM cur INTO @cust_id, @spending, @old_tier;
    END
    CLOSE cur; DEALLOCATE cur;
END;
GO
