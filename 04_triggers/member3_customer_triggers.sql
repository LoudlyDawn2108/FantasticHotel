-- =============================================
-- MEMBER 3: CUSTOMER & SERVICE MANAGEMENT
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
                
                -- Create upgrade notification for customer
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type, recipient_id
                )
                VALUES (
                    'TierUpgrade',
                    'Congratulations! You''ve been upgraded to ' + @new_tier + '!',
                    'Dear ' + @customer_name + ', thank you for your loyalty! ' +
                    'You have been upgraded from ' + @old_tier + ' to ' + @new_tier + ' tier. ' +
                    'Enjoy enhanced benefits including: ' +
                    CASE @new_tier
                        WHEN 'Silver' THEN '5% discount on all bookings, priority check-in.'
                        WHEN 'Gold' THEN '10% discount on all bookings, free room upgrade when available, late checkout.'
                        WHEN 'Platinum' THEN '15% discount on all bookings, guaranteed room upgrade, VIP lounge access, free breakfast.'
                        ELSE ''
                    END,
                    'CUSTOMERS',
                    @customer_id,
                    'Customer',
                    @customer_id
                );
                
                -- Create notification for management
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type
                )
                VALUES (
                    'TierUpgrade',
                    'Customer Tier Upgrade',
                    @customer_name + ' (ID: ' + CAST(@customer_id AS NVARCHAR) + ') ' +
                    'has been upgraded from ' + @old_tier + ' to ' + @new_tier + '. ' +
                    'Total spending: $' + CAST(@new_total_spending AS NVARCHAR),
                    'CUSTOMERS',
                    @customer_id,
                    'Management'
                );
            END
        END
        
        FETCH NEXT FROM tier_cursor INTO @customer_id, @old_tier, @new_total_spending, @customer_name;
    END
    
    CLOSE tier_cursor;
    DEALLOCATE tier_cursor;
END;
GO

-- =============================================
-- TRIGGER 2: trg_service_usage_notification
-- Creates notification when high-value service
-- is used (for tracking VIP experiences)
-- =============================================
CREATE OR ALTER TRIGGER trg_service_usage_notification
ON SERVICES_USED
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @usage_id INT;
    DECLARE @reservation_id INT;
    DECLARE @service_id INT;
    DECLARE @total_price DECIMAL(10,2);
    DECLARE @quantity INT;
    DECLARE @service_name NVARCHAR(100);
    DECLARE @category_name NVARCHAR(100);
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @room_number NVARCHAR(10);
    
    -- Process each inserted service usage
    DECLARE service_cursor CURSOR FOR
        SELECT 
            i.usage_id,
            i.reservation_id,
            i.service_id,
            i.total_price,
            i.quantity
        FROM inserted i
        WHERE i.total_price >= 100;  -- Only high-value services
    
    OPEN service_cursor;
    FETCH NEXT FROM service_cursor INTO @usage_id, @reservation_id, @service_id, @total_price, @quantity;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get service details
        SELECT 
            @service_name = s.service_name,
            @category_name = sc.category_name
        FROM SERVICES s
        INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
        WHERE s.service_id = @service_id;
        
        -- Get customer and room details
        SELECT 
            @customer_name = c.first_name + ' ' + c.last_name,
            @room_number = rm.room_number
        FROM RESERVATIONS r
        INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
        INNER JOIN ROOMS rm ON r.room_id = rm.room_id
        WHERE r.reservation_id = @reservation_id;
        
        -- Create notification for department
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, related_id, recipient_type
        )
        VALUES (
            'HighValueService',
            'High-Value Service Requested',
            @service_name + ' (x' + CAST(@quantity AS NVARCHAR) + ') ' +
            'requested by ' + @customer_name + ' in Room ' + @room_number + '. ' +
            'Total: $' + CAST(@total_price AS NVARCHAR) + '. ' +
            'Category: ' + @category_name,
            'SERVICES_USED',
            @usage_id,
            CASE 
                WHEN @category_name = 'Spa & Wellness' THEN 'Spa'
                WHEN @category_name = 'Room Service' OR @category_name = 'Food & Beverage' THEN 'F&B'
                WHEN @category_name = 'Transportation' THEN 'Concierge'
                ELSE 'Front Desk'
            END
        );
        
        -- If it's a VIP service (over $200), notify management
        IF @total_price >= 200
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'VIPService',
                'VIP Service Alert',
                'High-value service ($' + CAST(@total_price AS NVARCHAR) + ') ' +
                'booked by ' + @customer_name + ' (Room ' + @room_number + '): ' +
                @service_name,
                'SERVICES_USED',
                @usage_id,
                'Management'
            );
        END
        
        FETCH NEXT FROM service_cursor INTO @usage_id, @reservation_id, @service_id, @total_price, @quantity;
    END
    
    CLOSE service_cursor;
    DEALLOCATE service_cursor;
END;
GO

PRINT 'Member 3 Triggers created successfully.';
GO
