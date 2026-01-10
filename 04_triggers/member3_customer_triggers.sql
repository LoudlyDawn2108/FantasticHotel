-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- TRIGGERS (SIMPLIFIED - NO CURSORS)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_customer_tier_upgrade
-- Automatically upgrades membership tier when spending threshold reached
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
    
    -- Update tiers for all affected customers (SET-based, no cursor)
    UPDATE c
    SET 
        c.membership_tier = CASE 
            WHEN i.total_spending >= 50000 THEN 'Platinum'
            WHEN i.total_spending >= 20000 THEN 'Gold'
            WHEN i.total_spending >= 5000 THEN 'Silver'
            ELSE 'Bronze'
        END
    FROM CUSTOMERS c
    INNER JOIN inserted i ON c.customer_id = i.customer_id
    INNER JOIN deleted d ON c.customer_id = d.customer_id
    WHERE i.total_spending <> d.total_spending
    AND (
        (i.total_spending >= 50000 AND d.membership_tier IN ('Bronze', 'Silver', 'Gold')) OR
        (i.total_spending >= 20000 AND i.total_spending < 50000 AND d.membership_tier IN ('Bronze', 'Silver')) OR
        (i.total_spending >= 5000 AND i.total_spending < 20000 AND d.membership_tier = 'Bronze')
    );
    
    -- Create notifications for upgraded customers
    INSERT INTO NOTIFICATIONS (
        notification_type, title, message,
        related_table, related_id, recipient_type, recipient_id
    )
    SELECT 
        'TierUpgrade',
        'Upgraded to ' + c.membership_tier + ' Tier!',
        i.first_name + ' ' + i.last_name + ' upgraded from ' + d.membership_tier + ' to ' + c.membership_tier,
        'CUSTOMERS',
        i.customer_id,
        'Customer',
        i.customer_id
    FROM inserted i
    INNER JOIN deleted d ON i.customer_id = d.customer_id
    INNER JOIN CUSTOMERS c ON i.customer_id = c.customer_id
    WHERE i.total_spending <> d.total_spending
    AND c.membership_tier <> d.membership_tier;
END;
GO

-- =============================================
-- TRIGGER 2: trg_service_usage_notification
-- Creates notification for high-value services (>= $200)
-- =============================================
CREATE OR ALTER TRIGGER trg_service_usage_notification
ON SERVICES_USED
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create notifications for high-value services (SET-based, no cursor)
    INSERT INTO NOTIFICATIONS (
        notification_type, title, message,
        related_table, related_id, recipient_type
    )
    SELECT 
        'HighValueService',
        'High-Value Service: $' + CAST(i.total_price AS NVARCHAR),
        s.service_name + ' (x' + CAST(i.quantity AS NVARCHAR) + ') - ' +
        c.first_name + ' ' + c.last_name + ' in Room ' + rm.room_number,
        'SERVICES_USED',
        i.usage_id,
        CASE 
            WHEN sc.category_name = 'Spa & Wellness' THEN 'Spa'
            WHEN sc.category_name IN ('Room Service', 'Food & Beverage') THEN 'F&B'
            WHEN sc.category_name = 'Transportation' THEN 'Concierge'
            ELSE 'Front Desk'
        END
    FROM inserted i
    INNER JOIN SERVICES s ON i.service_id = s.service_id
    INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
    INNER JOIN RESERVATIONS r ON i.reservation_id = r.reservation_id
    INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    INNER JOIN ROOMS rm ON r.room_id = rm.room_id
    WHERE i.total_price >= 200;  -- Only high-value services
END;
GO

PRINT 'Ninh Triggers created successfully.';
GO
