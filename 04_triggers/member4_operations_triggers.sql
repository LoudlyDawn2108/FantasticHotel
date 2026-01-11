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
            WHEN 'Occupied' THEN N'Khách đã nhận phòng'
            WHEN 'Cleaning' THEN N'Cần dọn dẹp'
            WHEN 'Available' THEN N'Phòng sẵn sàng'
            WHEN 'Maintenance' THEN N'Cần bảo trì'
            ELSE N'Thay đổi trạng thái'
        END
    FROM inserted i 
    JOIN deleted d ON i.room_id = d.room_id 
    WHERE i.status <> d.status;  -- Chỉ ghi khi thực sự thay đổi
END;
GO

-- =============================================
-- TRIGGER 2: trg_update_employee_availability
-- Mục đích: Đánh dấu nhân viên bận khi được giao task ưu tiên cao
-- Kích hoạt: Khi INSERT hoặc UPDATE (gán assigned_to) yêu cầu bảo trì
-- =============================================
CREATE OR ALTER TRIGGER trg_update_employee_availability
ON MAINTENANCE_REQUESTS AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Nếu là UPDATE mà không thay đổi assigned_to → bỏ qua
    IF EXISTS (SELECT 1 FROM deleted) AND NOT UPDATE(assigned_to)
        RETURN;
    
    -- Đánh dấu nhân viên mới được giao là bận (nếu task Critical/High)
    UPDATE EMPLOYEES SET is_available = 0
    WHERE employee_id IN (
        SELECT i.assigned_to 
        FROM inserted i
        LEFT JOIN deleted d ON i.request_id = d.request_id
        WHERE i.priority IN ('Critical','High') 
        AND i.assigned_to IS NOT NULL
        AND (d.request_id IS NULL                      -- INSERT mới
             OR d.assigned_to IS NULL                  -- UPDATE từ NULL
             OR d.assigned_to <> i.assigned_to)        -- UPDATE đổi người
    );
END;
GO

-- =============================================
-- TRIGGER 3: trg_restore_employee_availability
-- Mục đích: Khôi phục trạng thái rảnh cho nhân viên khi hoàn thành task
-- Kích hoạt: Khi UPDATE yêu cầu bảo trì thành Completed
-- Lưu ý: Chỉ set available khi không còn task Critical/High nào khác
-- =============================================
CREATE OR ALTER TRIGGER trg_restore_employee_availability
ON MAINTENANCE_REQUESTS AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    -- Chỉ xử lý khi cột status được cập nhật
    IF NOT UPDATE(status) RETURN;
    
    -- Khôi phục trạng thái rảnh CHỈ KHI không còn task Critical/High nào khác đang xử lý
    UPDATE EMPLOYEES SET is_available = 1
    WHERE employee_id IN (
        SELECT i.assigned_to 
        FROM inserted i 
        JOIN deleted d ON i.request_id = d.request_id
        WHERE i.status = 'Completed'       -- Trạng thái mới là Completed
        AND d.status <> 'Completed'        -- Trạng thái cũ khác Completed
        AND i.assigned_to IS NOT NULL
    )
    -- Kiểm tra không còn task Critical/High nào khác đang xử lý
    AND NOT EXISTS (
        SELECT 1 FROM MAINTENANCE_REQUESTS mr
        WHERE mr.assigned_to = EMPLOYEES.employee_id
        AND mr.status NOT IN ('Completed', 'Cancelled')
        AND mr.priority IN ('Critical', 'High')
    );
END;
GO

PRINT N'Tung: Đã tạo 3 trigger thành công!';
GO
