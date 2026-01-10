-- =============================================
-- TUNG (Member 4): THỦ TỤC - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- THỦ TỤC 1: sp_create_maintenance_request
-- Mục đích: Tạo yêu cầu bảo trì và tự động phân công nhân viên
-- Có TRANSACTION để đảm bảo tính toàn vẹn dữ liệu
-- =============================================
CREATE OR ALTER PROCEDURE sp_create_maintenance_request
    @room_id INT,                       -- Mã phòng cần bảo trì
    @title NVARCHAR(200),               -- Tiêu đề yêu cầu
    @priority NVARCHAR(20) = 'Medium',  -- Độ ưu tiên (mặc định Medium)
    @req_id INT OUTPUT,                 -- OUTPUT: Mã yêu cầu được tạo
    @assigned NVARCHAR(100) OUTPUT      -- OUTPUT: Tên nhân viên được giao
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @room_num NVARCHAR(10), @status NVARCHAR(20), @emp_id INT, @dept_id INT;
    
    BEGIN TRY
        -- Bắt đầu transaction
        BEGIN TRANSACTION;
        
        -- Kiểm tra phòng có tồn tại không
        SELECT @room_num = room_number, @status = status 
        FROM ROOMS WHERE room_id = @room_id;
        
        IF @room_num IS NULL 
        BEGIN 
            ROLLBACK; 
            RETURN -1;  -- Lỗi: Phòng không tồn tại
        END
        
        -- Lấy mã phòng ban Maintenance
        SELECT @dept_id = department_id 
        FROM DEPARTMENTS WHERE department_name = 'Maintenance';
        
        -- Tìm nhân viên có ít yêu cầu đang xử lý nhất
        SELECT TOP 1 @emp_id = e.employee_id
        FROM EMPLOYEES e
        LEFT JOIN (
            SELECT assigned_to, COUNT(*) AS cnt 
            FROM MAINTENANCE_REQUESTS 
            WHERE status IN ('Open','InProgress') 
            GROUP BY assigned_to
        ) mr ON e.employee_id = mr.assigned_to
        WHERE e.department_id = @dept_id AND e.is_active = 1 AND e.is_available = 1
        ORDER BY ISNULL(mr.cnt, 0), e.hire_date;
        
        -- Lấy tên nhân viên được giao
        SELECT @assigned = ISNULL(first_name + ' ' + last_name, 'Chưa phân công') 
        FROM EMPLOYEES WHERE employee_id = @emp_id;
        IF @assigned IS NULL SET @assigned = 'Chưa phân công';
        
        -- Tạo yêu cầu bảo trì
        INSERT INTO MAINTENANCE_REQUESTS (room_id, assigned_to, title, priority, status)
        VALUES (@room_id, @emp_id, @title, @priority, 'Open');
        SET @req_id = SCOPE_IDENTITY();
        
        -- Nếu độ ưu tiên cao, đánh dấu phòng là đang bảo trì
        IF @priority IN ('Critical','High') AND @status = 'Available'
            UPDATE ROOMS SET status = 'Maintenance' WHERE room_id = @room_id;
        
        -- Commit transaction
        COMMIT;
        RETURN 0;  -- Thành công
    END TRY
    BEGIN CATCH
        -- Rollback nếu có lỗi
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @req_id = NULL; 
        SET @assigned = NULL;
        RETURN -1;  -- Lỗi
    END CATCH
END;
GO

-- =============================================
-- THỦ TỤC 2: sp_complete_maintenance
-- Mục đích: Hoàn thành yêu cầu bảo trì và cập nhật trạng thái phòng
-- Có TRANSACTION để đảm bảo tính toàn vẹn dữ liệu
-- =============================================
CREATE OR ALTER PROCEDURE sp_complete_maintenance
    @req_id INT,                        -- Mã yêu cầu cần hoàn thành
    @cost DECIMAL(10,2) = NULL,         -- Chi phí thực tế (tùy chọn)
    @hours DECIMAL(10,2) OUTPUT         -- OUTPUT: Thời gian xử lý (giờ)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status NVARCHAR(20), @room_id INT, @created DATETIME, @has_res BIT = 0;
    
    BEGIN TRY
        -- Bắt đầu transaction
        BEGIN TRANSACTION;
        
        -- Lấy thông tin yêu cầu
        SELECT @status = status, @room_id = room_id, @created = created_at
        FROM MAINTENANCE_REQUESTS WHERE request_id = @req_id;
        
        -- Kiểm tra trạng thái hợp lệ
        IF @status IN ('Completed','Cancelled') 
        BEGIN 
            ROLLBACK; 
            RETURN -1;  -- Lỗi: Yêu cầu đã hoàn thành hoặc hủy
        END
        
        -- Tính thời gian xử lý (phút chuyển sang giờ)
        SET @hours = CAST(DATEDIFF(MINUTE, @created, GETDATE()) AS DECIMAL(10,2)) / 60;
        
        -- Cập nhật yêu cầu thành hoàn thành
        UPDATE MAINTENANCE_REQUESTS 
        SET status = 'Completed', 
            actual_cost = @cost,
            completed_at = GETDATE() 
        WHERE request_id = @req_id;
        
        -- Kiểm tra phòng có đặt chỗ đang hoạt động không
        IF EXISTS (
            SELECT 1 FROM RESERVATIONS 
            WHERE room_id = @room_id 
            AND status IN ('Confirmed','CheckedIn') 
            AND GETDATE() BETWEEN check_in_date AND check_out_date
        )
            SET @has_res = 1;
        
        -- Cập nhật trạng thái phòng
        UPDATE ROOMS 
        SET status = CASE WHEN @has_res = 1 THEN 'Occupied' ELSE 'Available' END
        WHERE room_id = @room_id AND status = 'Maintenance';
        
        -- Commit transaction
        COMMIT;
        RETURN 0;  -- Thành công
    END TRY
    BEGIN CATCH
        -- Rollback nếu có lỗi
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @hours = NULL;
        RETURN -1;  -- Lỗi
    END CATCH
END;
GO

PRINT 'Tung: Đã tạo 2 thủ tục thành công!';
GO
