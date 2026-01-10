-- Phuc: TRIGGERS (Simplified)
USE HotelManagement;
GO

-- trg_reservation_status_change: Update room on reservation status change
CREATE OR ALTER TRIGGER trg_reservation_status_change
ON RESERVATIONS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(status) RETURN;
    
    -- Handle status changes
    UPDATE r SET status = CASE 
        WHEN i.status = 'CheckedIn' THEN 'Occupied'
        WHEN i.status = 'CheckedOut' THEN 'Cleaning'
        WHEN i.status IN ('Cancelled','NoShow') THEN 'Available'
        ELSE r.status END
    FROM ROOMS r
    JOIN inserted i ON r.room_id = i.room_id
    JOIN deleted d ON i.reservation_id = d.reservation_id
    WHERE i.status <> d.status;
    
    -- Set actual check-in/out times
    UPDATE RESERVATIONS SET actual_check_in = GETDATE()
    WHERE reservation_id IN (SELECT reservation_id FROM inserted WHERE status = 'CheckedIn')
    AND actual_check_in IS NULL;
    
    UPDATE RESERVATIONS SET actual_check_out = GETDATE()
    WHERE reservation_id IN (SELECT reservation_id FROM inserted WHERE status = 'CheckedOut')
    AND actual_check_out IS NULL;
END;
GO

-- trg_reservation_audit: Log reservation changes
CREATE OR ALTER TRIGGER trg_reservation_audit
ON RESERVATIONS AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @op NVARCHAR(10) = CASE 
        WHEN EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted) THEN 'UPDATE'
        WHEN EXISTS(SELECT 1 FROM inserted) THEN 'INSERT' ELSE 'DELETE' END;
    
    IF @op = 'INSERT'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, new_values, changed_by)
        SELECT 'RESERVATIONS', 'INSERT', reservation_id, 
            CONCAT('cust:',customer_id,',room:',room_id,',status:',status), SYSTEM_USER FROM inserted;
    
    IF @op = 'UPDATE'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, new_values, changed_by)
        SELECT 'RESERVATIONS', 'UPDATE', i.reservation_id,
            CONCAT('status:',d.status,',total:',d.total_amount),
            CONCAT('status:',i.status,',total:',i.total_amount), SYSTEM_USER
        FROM inserted i JOIN deleted d ON i.reservation_id = d.reservation_id;
    
    IF @op = 'DELETE'
        INSERT INTO AUDIT_LOGS (table_name, operation, record_id, old_values, changed_by)
        SELECT 'RESERVATIONS', 'DELETE', reservation_id, 
            CONCAT('cust:',customer_id,',room:',room_id), SYSTEM_USER FROM deleted;
END;
GO
