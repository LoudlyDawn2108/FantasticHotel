-- =============================================
-- Tung: QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- TRIGGER
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_room_status_history
-- Ghi log tất cả thay đổi trạng thái phòng
-- =============================================
CREATE OR ALTER TRIGGER trg_room_status_history
ON ROOMS
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Chỉ xử lý khi cột status thay đổi
    IF NOT UPDATE(status)
        RETURN;
    
    -- Ghi log vào bảng lịch sử
    INSERT INTO ROOM_STATUS_HISTORY (room_id, old_status, new_status, changed_at, reason)
    SELECT 
        i.room_id,
        d.status,
        i.status,
        GETDATE(),
        CASE 
            WHEN i.status = 'Occupied' THEN 'Guest checked in'
            WHEN i.status = 'Cleaning' THEN 'Guest checked out, needs cleaning'
            WHEN i.status = 'Available' AND d.status = 'Cleaning' THEN 'Room cleaned and ready'
            WHEN i.status = 'Available' AND d.status = 'Maintenance' THEN 'Maintenance completed'
            WHEN i.status = 'Maintenance' THEN 'Maintenance required'
            ELSE 'Status changed'
        END
    FROM inserted i
    INNER JOIN deleted d ON i.room_id = d.room_id
    WHERE i.status <> d.status;
    
    -- Thông báo cho Housekeeping khi phòng cần dọn
    INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
    SELECT 
        'RoomCleaning',
        'Room Ready for Cleaning',
        'Room ' + i.room_number + ' is now ready for cleaning.',
        'ROOMS',
        i.room_id,
        'Housekeeping'
    FROM inserted i
    INNER JOIN deleted d ON i.room_id = d.room_id
    WHERE i.status = 'Cleaning' AND d.status <> 'Cleaning';
    
    -- Thông báo cho Front Desk khi phòng sẵn sàng
    INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
    SELECT 
        'RoomAvailable',
        'Room Now Available',
        'Room ' + i.room_number + ' is now available for check-in.',
        'ROOMS',
        i.room_id,
        'Front Desk'
    FROM inserted i
    INNER JOIN deleted d ON i.room_id = d.room_id
    WHERE i.status = 'Available' AND d.status IN ('Cleaning', 'Maintenance');
END;
GO

-- =============================================
-- TRIGGER 2: trg_high_priority_maintenance
-- Cảnh báo khi có yêu cầu bảo trì khẩn cấp (High/Critical)
-- =============================================
CREATE OR ALTER TRIGGER trg_high_priority_maintenance
ON MAINTENANCE_REQUESTS
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Thông báo cho bộ phận Bảo trì khi có yêu cầu High/Critical
    INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
    SELECT 
        'UrgentMaintenance',
        CASE i.priority 
            WHEN 'Critical' THEN '🚨 CRITICAL Maintenance'
            ELSE '⚠️ High Priority Maintenance'
        END,
        'Room ' + r.room_number + ': ' + i.title + '. Priority: ' + i.priority,
        'MAINTENANCE_REQUESTS',
        i.request_id,
        'Maintenance'
    FROM inserted i
    INNER JOIN ROOMS r ON i.room_id = r.room_id
    WHERE i.priority IN ('High', 'Critical');
    
    -- Thông báo thêm cho Management nếu Critical
    INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
    SELECT 
        'CriticalAlert',
        '🚨 CRITICAL Maintenance Alert',
        'CRITICAL maintenance needed for Room ' + r.room_number + ': ' + i.title,
        'MAINTENANCE_REQUESTS',
        i.request_id,
        'Management'
    FROM inserted i
    INNER JOIN ROOMS r ON i.room_id = r.room_id
    WHERE i.priority = 'Critical';
END;
GO

PRINT 'Tung Triggers created successfully.';
GO
