-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- TRIGGERS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_customer_tier_upgrade
-- Automatically upgrades membership tier when
-- points threshold is reached
-- =============================================
CREATE OR ALTER TRIGGER trg_customer_tier_upgrade
ON CUSTOMERS
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Only proceed if total_spending was updated
    IF NOT UPDATE(total_spending)
        RETURN;
    
    DECLARE @customer_id INT;
    DECLARE @old_tier NVARCHAR(20);
    DECLARE @new_tier NVARCHAR(20);
    DECLARE @new_total_spending DECIMAL(15,2);
    DECLARE @customer_name NVARCHAR(100);
    
    -- Use cursor to handle multiple customer updates
    DECLARE tier_cursor CURSOR FOR
        SELECT 
            i.customer_id,
            d.membership_tier AS old_tier,
            i.total_spending,
            i.first_name + ' ' + i.last_name AS customer_name
        FROM inserted i
        INNER JOIN deleted d ON i.customer_id = d.customer_id
        WHERE i.total_spending <> d.total_spending;
    
    OPEN tier_cursor;
    FETCH NEXT FROM tier_cursor INTO @customer_id, @old_tier, @new_total_spending, @customer_name;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calculate new tier based on total spending
        SET @new_tier = dbo.fn_get_customer_tier(@new_total_spending);
        
        -- Check if tier should be upgraded (not downgraded)
        IF @new_tier <> @old_tier
        BEGIN
            -- Only upgrade, never downgrade
            DECLARE @tier_order INT;
            DECLARE @old_tier_order INT;
            
            SELECT @tier_order = CASE @new_tier
                WHEN 'Bronze' THEN 1
                WHEN 'Silver' THEN 2
                WHEN 'Gold' THEN 3
                WHEN 'Platinum' THEN 4
            END;
            
            SELECT @old_tier_order = CASE @old_tier
                WHEN 'Bronze' THEN 1
                WHEN 'Silver' THEN 2
                WHEN 'Gold' THEN 3
                WHEN 'Platinum' THEN 4
            END;
            
            IF @tier_order > @old_tier_order
            BEGIN
                -- Update tier (without triggering this trigger again)
                UPDATE CUSTOMERS
                SET membership_tier = @new_tier
                WHERE customer_id = @customer_id
                AND membership_tier = @old_tier;  -- Prevent recursion
            END
        END
        
        FETCH NEXT FROM tier_cursor INTO @customer_id, @old_tier, @new_total_spending, @customer_name;
    END
    
    CLOSE tier_cursor;
    DEALLOCATE tier_cursor;
END;
GO

-- Note: trg_service_usage_notification removed - was only used for notifications
-- High-value services can be tracked via views instead

PRINT 'Ninh Triggers created successfully.';
GO
