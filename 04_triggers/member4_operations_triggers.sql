-- Tung: TRIGGERS (Simplified)
USE HotelManagement;
GO

-- trg_room_status_history: Log room status changes
CREATE OR ALTER TRIGGER trg_room_status_history
ON ROOMS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    
    INSERT INTO ROOM_STATUS_HISTORY (room_id, old_status, new_status, changed_at, reason)
    SELECT i.room_id, d.status, i.status, GETDATE(),
        CASE i.status
            WHEN 'Occupied' THEN 'Guest checked in'
            WHEN 'Cleaning' THEN 'Needs cleaning'
            WHEN 'Available' THEN 'Ready'
            WHEN 'Maintenance' THEN 'Maintenance required'
            ELSE 'Status changed' END
    FROM inserted i JOIN deleted d ON i.room_id = d.room_id WHERE i.status <> d.status;
END;
GO

-- trg_high_priority_maintenance: Track high priority requests
CREATE OR ALTER TRIGGER trg_high_priority_maintenance
ON MAINTENANCE_REQUESTS AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    -- High priority tracked via vw_maintenance_dashboard
END;
GO
