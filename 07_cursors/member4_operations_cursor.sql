-- =============================================
-- TUNG (Member 4): CON TRỎ - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CON TRỎ 1: Duyệt và phân công task chưa có người xử lý
-- Mục đích: Tự động phân công yêu cầu bảo trì cho nhân viên rảnh
-- =============================================
DECLARE @request_id INT;
DECLARE @room_number NVARCHAR(10);
DECLARE @title NVARCHAR(200);
DECLARE @priority NVARCHAR(20);
DECLARE @assigned_to INT;

-- Bước 1: Khai báo con trỏ - lấy các yêu cầu chưa được phân công
DECLARE maintenance_cursor CURSOR FOR
    SELECT 
        mr.request_id,
        r.room_number,
        mr.title,
        mr.priority
    FROM MAINTENANCE_REQUESTS mr
    INNER JOIN ROOMS r ON mr.room_id = r.room_id
    WHERE mr.assigned_to IS NULL        -- Chưa có người xử lý
    AND mr.status = 'Open'              -- Trạng thái đang mở
    ORDER BY 
        CASE mr.priority                -- Ưu tiên theo độ quan trọng
            WHEN 'Critical' THEN 1 
            WHEN 'High' THEN 2 
            WHEN 'Medium' THEN 3 
            ELSE 4 
        END;

-- Bước 2: Mở con trỏ
OPEN maintenance_cursor;

-- Bước 3: Lấy dòng đầu tiên
FETCH NEXT FROM maintenance_cursor INTO @request_id, @room_number, @title, @priority;

-- Bước 4: Duyệt qua từng dòng
WHILE @@FETCH_STATUS = 0
BEGIN
    -- Tìm nhân viên bảo trì đang rảnh
    SELECT TOP 1 @assigned_to = employee_id
    FROM EMPLOYEES
    WHERE department_id = (SELECT department_id FROM DEPARTMENTS WHERE department_name = 'Maintenance')
    AND is_available = 1
    ORDER BY NEWID();  -- Chọn ngẫu nhiên
    
    -- Kiểm tra có tìm được nhân viên không
    IF @assigned_to IS NOT NULL
    BEGIN
        -- Cập nhật yêu cầu với nhân viên được giao
        UPDATE MAINTENANCE_REQUESTS
        SET assigned_to = @assigned_to
        WHERE request_id = @request_id;
        
        PRINT N'Đã phân công Yêu cầu #' + CAST(@request_id AS NVARCHAR) + 
              N' - Phòng ' + @room_number + 
              N' - Độ ưu tiên: ' + @priority;
    END
    ELSE
    BEGIN
        PRINT N'Không có nhân viên rảnh cho Yêu cầu #' + CAST(@request_id AS NVARCHAR);
    END
    
    -- Lấy dòng tiếp theo
    FETCH NEXT FROM maintenance_cursor INTO @request_id, @room_number, @title, @priority;
END

-- Bước 5: Đóng và giải phóng con trỏ
CLOSE maintenance_cursor;
DEALLOCATE maintenance_cursor;

PRINT N'=== Con trỏ 1: Hoàn thành phân công tự động ===';
GO


-- =============================================
-- CON TRỎ 2: Thống kê số task theo từng nhân viên
-- Mục đích: Báo cáo khối lượng công việc của đội bảo trì
-- =============================================
DECLARE @emp_id INT;
DECLARE @emp_name NVARCHAR(100);
DECLARE @task_count INT;

-- Khai báo con trỏ - lấy thống kê task theo nhân viên
DECLARE staff_cursor CURSOR FOR
    SELECT 
        e.employee_id,
        e.first_name + ' ' + e.last_name AS emp_name,
        COUNT(mr.request_id) AS task_count
    FROM EMPLOYEES e
    LEFT JOIN MAINTENANCE_REQUESTS mr ON e.employee_id = mr.assigned_to
    WHERE e.department_id = (SELECT department_id FROM DEPARTMENTS WHERE department_name = 'Maintenance')
    GROUP BY e.employee_id, e.first_name, e.last_name
    ORDER BY task_count DESC;

-- Mở con trỏ
OPEN staff_cursor;
FETCH NEXT FROM staff_cursor INTO @emp_id, @emp_name, @task_count;

-- Duyệt và in báo cáo
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT @emp_name + N': ' + CAST(@task_count AS NVARCHAR) + N' task';
    
    FETCH NEXT FROM staff_cursor INTO @emp_id, @emp_name, @task_count;
END

-- Đóng và giải phóng
CLOSE staff_cursor;
DEALLOCATE staff_cursor;

PRINT N'=== Con trỏ 2: Hoàn thành thống kê ===';
GO
