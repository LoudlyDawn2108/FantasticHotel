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
END;
GO

-- =============================================
-- TRIGGER 2: trg_high_priority_maintenance
-- Cảnh báo khi có yêu cầu bảo trì khẩn cấp (High/Critical)
-- (Notification functionality removed - use vw_maintenance_dashboard instead)
-- =============================================
CREATE OR ALTER TRIGGER trg_high_priority_maintenance
ON MAINTENANCE_REQUESTS
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    -- High priority maintenance is tracked via vw_maintenance_dashboard with SLA status
    -- No direct notification needed - staff should check dashboard
END;
GO

PRINT 'Tung Triggers created successfully.';
GO
