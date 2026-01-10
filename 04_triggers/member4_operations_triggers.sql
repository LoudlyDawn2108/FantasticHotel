-- =============================================
-- TUNG (Member 4): TRIGGER - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_room_status_history
-- Mục đích: Ghi lại lịch sử thay đổi trạng thái phòng
-- Kích hoạt: Khi UPDATE trạng thái phòng trong bảng ROOMS
-- =============================================
CREATE OR ALTER TRIGGER trg_room_status_history
ON ROOMS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    -- Chỉ thực hiện khi cột status được cập nhật
    IF NOT UPDATE(status) RETURN;
    
    -- Ghi lại lịch sử thay đổi
    INSERT INTO ROOM_STATUS_HISTORY (room_id, old_status, new_status, changed_at, reason)
    SELECT 
        i.room_id,                  -- Mã phòng
        d.status,                   -- Trạng thái cũ
        i.status,                   -- Trạng thái mới
        GETDATE(),                  -- Thời điểm thay đổi
        CASE i.status               -- Lý do thay đổi
            WHEN 'Occupied' THEN 'Khách đã nhận phòng'
            WHEN 'Cleaning' THEN 'Cần dọn dẹp'
            WHEN 'Available' THEN 'Phòng sẵn sàng'
            WHEN 'Maintenance' THEN 'Cần bảo trì'
            ELSE 'Thay đổi trạng thái' 
        END
    FROM inserted i 
    JOIN deleted d ON i.room_id = d.room_id 
    WHERE i.status <> d.status;  -- Chỉ ghi khi thực sự thay đổi
END;
GO

-- =============================================
-- TRIGGER 2: trg_update_employee_availability
-- Mục đích: Đánh dấu nhân viên bận khi được giao task ưu tiên cao
-- Kích hoạt: Khi INSERT yêu cầu bảo trì mới
-- =============================================
CREATE OR ALTER TRIGGER trg_update_employee_availability
ON MAINTENANCE_REQUESTS AFTER INSERT AS
BEGIN
    SET NOCOUNT ON;
    
    -- Đánh dấu nhân viên là không rảnh nếu được giao task Critical/High
    UPDATE EMPLOYEES SET is_available = 0
    WHERE employee_id IN (
        SELECT assigned_to FROM inserted 
        WHERE priority IN ('Critical','High') AND assigned_to IS NOT NULL
    );
END;
GO

-- =============================================
-- TRIGGER 3: trg_restore_employee_availability
-- Mục đích: Khôi phục trạng thái rảnh cho nhân viên khi hoàn thành task
-- Kích hoạt: Khi UPDATE yêu cầu bảo trì thành Completed
-- =============================================
CREATE OR ALTER TRIGGER trg_restore_employee_availability
ON MAINTENANCE_REQUESTS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    -- Khôi phục trạng thái rảnh khi task hoàn thành
    UPDATE EMPLOYEES SET is_available = 1
    WHERE employee_id IN (
        SELECT i.assigned_to 
        FROM inserted i 
        JOIN deleted d ON i.request_id = d.request_id
        WHERE i.status = 'Completed'       -- Trạng thái mới là Completed
        AND d.status <> 'Completed'        -- Trạng thái cũ khác Completed
        AND i.assigned_to IS NOT NULL
    );
END;
GO

PRINT 'Tung: Đã tạo 3 trigger thành công!';
GO
