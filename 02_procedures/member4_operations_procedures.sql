-- =============================================
-- Tung: QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- THỦ TỤC LƯU TRỮ (STORED PROCEDURES)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- THỦ TỤC 1: sp_create_maintenance_request
-- Tạo yêu cầu bảo trì với mức độ ưu tiên
-- và tự động phân công nhân viên
-- Authorization: Housekeeping/Maintenance Staff+ (level 30)
-- =============================================
CREATE OR ALTER PROCEDURE sp_create_maintenance_request
    @user_id INT,                           -- Required: calling user for authorization
    @room_id INT,
    @title NVARCHAR(200),
    @description NVARCHAR(1000) = NULL,
    @priority NVARCHAR(20) = 'Medium',
    @estimated_cost DECIMAL(10,2) = NULL,
    @request_id INT OUTPUT,
    @assigned_employee NVARCHAR(100) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Authorization check - Housekeeping/Maintenance Staff or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 30
    BEGIN
        SET @message = 'Access denied. Housekeeping or Maintenance Staff or higher required.';
        SET @request_id = NULL;
        SET @assigned_employee = NULL;
        RETURN -403;
    END
    
    DECLARE @room_number NVARCHAR(10);
    DECLARE @room_status NVARCHAR(20);
    DECLARE @assigned_to INT;
    DECLARE @maintenance_dept_id INT;
    DECLARE @available_staff_count INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Kiểm tra phòng có tồn tại không
        SELECT 
            @room_number = room_number,
            @room_status = status
        FROM ROOMS
        WHERE room_id = @room_id AND is_active = 1;
        
        IF @room_number IS NULL
        BEGIN
            SET @message = 'Error: Room not found or inactive.';
            SET @request_id = NULL;
            SET @assigned_employee = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Kiểm tra priority hợp lệ
        IF @priority NOT IN ('Low', 'Medium', 'High', 'Critical')
        BEGIN
            SET @message = 'Error: Invalid priority. Accepted values: Low, Medium, High, Critical.';
            SET @request_id = NULL;
            SET @assigned_employee = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Lấy ID bộ phận Bảo trì
        SELECT @maintenance_dept_id = department_id
        FROM DEPARTMENTS
        WHERE department_name = 'Maintenance';
        
        -- Đếm số nhân viên có sẵn
        SET @available_staff_count = dbo.fn_get_available_staff(@maintenance_dept_id, CAST(GETDATE() AS DATE));
        
        -- Tìm nhân viên có ít việc nhất để phân công
        SELECT TOP 1 @assigned_to = e.employee_id
        FROM EMPLOYEES e
        LEFT JOIN (
            SELECT assigned_to, COUNT(*) AS open_requests
            FROM MAINTENANCE_REQUESTS
            WHERE status IN ('Open', 'InProgress')
            GROUP BY assigned_to
        ) mr ON e.employee_id = mr.assigned_to
        WHERE e.department_id = @maintenance_dept_id
        AND e.is_active = 1
        AND e.is_available = 1
        ORDER BY ISNULL(mr.open_requests, 0) ASC, e.hire_date ASC;
        
        -- Nếu không có nhân viên rảnh, vẫn tạo request nhưng chưa phân công
        IF @assigned_to IS NULL
        BEGIN
            SET @assigned_employee = 'Unassigned (No available staff)';
        END
        ELSE
        BEGIN
            SELECT @assigned_employee = first_name + ' ' + last_name
            FROM EMPLOYEES
            WHERE employee_id = @assigned_to;
        END
        
        -- Tạo yêu cầu bảo trì
        INSERT INTO MAINTENANCE_REQUESTS (
            room_id, assigned_to, title, description,
            priority, status, estimated_cost, created_by
        )
        VALUES (
            @room_id, @assigned_to, @title, @description,
            @priority, 'Open', @estimated_cost, @created_by
        );
        
        SET @request_id = SCOPE_IDENTITY();
        
        -- Nếu priority là Critical hoặc High, cập nhật trạng thái phòng
        IF @priority IN ('Critical', 'High') AND @room_status = 'Available'
        BEGIN
            UPDATE ROOMS
            SET status = 'Maintenance', updated_at = GETDATE()
            WHERE room_id = @room_id;
        END
        
        COMMIT TRANSACTION;
        
        SET @message = 'Maintenance request created successfully. Request #' + CAST(@request_id AS NVARCHAR) +
                       ' for Room ' + @room_number + '. ' +
                       'Assigned to: ' + @assigned_employee;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @request_id = NULL;
        SET @assigned_employee = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- THỦ TỤC 2: sp_complete_maintenance
-- Hoàn thành yêu cầu bảo trì, cập nhật trạng thái phòng
-- và tính toán các chỉ số phản hồi
-- Authorization: Maintenance Staff+ (level 30)
-- =============================================
CREATE OR ALTER PROCEDURE sp_complete_maintenance
    @user_id INT,                           -- Required: calling user for authorization
    @request_id INT,
    @actual_cost DECIMAL(10,2) = NULL,
    @completion_notes NVARCHAR(500) = NULL,
    @response_time_hours DECIMAL(10,2) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Authorization check - Maintenance Staff or higher required
    IF dbo.fn_get_user_role_level(@user_id) < 30
    BEGIN
        SET @message = 'Access denied. Maintenance Staff or higher required.';
        SET @response_time_hours = NULL;
        RETURN -403;
    END
    
    DECLARE @current_status NVARCHAR(20);
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @priority NVARCHAR(20);
    DECLARE @created_at DATETIME;
    DECLARE @started_at DATETIME;
    DECLARE @has_active_reservation BIT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Lấy thông tin yêu cầu bảo trì
        SELECT 
            @current_status = status,
            @room_id = room_id,
            @priority = priority,
            @created_at = created_at,
            @started_at = started_at
        FROM MAINTENANCE_REQUESTS
        WHERE request_id = @request_id;
        
        -- Kiểm tra yêu cầu có tồn tại không
        IF @current_status IS NULL
        BEGIN
            SET @message = 'Error: Maintenance request not found.';
            SET @response_time_hours = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Kiểm tra đã hoàn thành hoặc hủy chưa
        IF @current_status IN ('Completed', 'Cancelled')
        BEGIN
            SET @message = 'Error: Request is already ' + @current_status + '.';
            SET @response_time_hours = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Lấy số phòng
        SELECT @room_number = room_number FROM ROOMS WHERE room_id = @room_id;
        
        -- Tính thời gian phản hồi (từ lúc tạo đến bây giờ)
        SET @response_time_hours = CAST(DATEDIFF(MINUTE, @created_at, GETDATE()) AS DECIMAL(10,2)) / 60;
        
        -- Cập nhật yêu cầu thành Completed
        UPDATE MAINTENANCE_REQUESTS
        SET 
            status = 'Completed',
            actual_cost = ISNULL(@actual_cost, estimated_cost),
            completed_at = GETDATE(),
            started_at = ISNULL(@started_at, GETDATE()),
            description = CASE 
                WHEN @completion_notes IS NOT NULL 
                THEN description + CHAR(13) + CHAR(10) + 'Completion Notes: ' + @completion_notes
                ELSE description
            END
        WHERE request_id = @request_id;
        
        -- Kiểm tra phòng có đặt chỗ đang hoạt động không
        IF EXISTS (
            SELECT 1 FROM RESERVATIONS
            WHERE room_id = @room_id
            AND status IN ('Confirmed', 'CheckedIn')
            AND GETDATE() BETWEEN check_in_date AND check_out_date
        )
        BEGIN
            SET @has_active_reservation = 1;
        END
        
        -- Cập nhật trạng thái phòng dựa trên có đặt chỗ hay không
        UPDATE ROOMS
        SET 
            status = CASE 
                WHEN @has_active_reservation = 1 THEN 'Occupied'
                ELSE 'Available'
            END,
            updated_at = GETDATE()
        WHERE room_id = @room_id
        AND status = 'Maintenance';
        
        -- Thông báo hoàn thành cho Front Desk
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, related_id, recipient_type
        )
        VALUES (
            'MaintenanceComplete',
            'Maintenance Completed',
            'Request #' + CAST(@request_id AS NVARCHAR) + ' for Room ' + @room_number + 
            ' completed. Response time: ' + CAST(ROUND(@response_time_hours, 1) AS NVARCHAR) + ' hours.',
            'MAINTENANCE_REQUESTS',
            @request_id,
            'Front Desk'
        );
        
        COMMIT TRANSACTION;
        
        SET @message = 'Maintenance completed successfully. Request #' + CAST(@request_id AS NVARCHAR) +
                       '. Room ' + @room_number + ' is now ' + 
                       CASE WHEN @has_active_reservation = 1 THEN 'Occupied' ELSE 'Available' END +
                       '. Response time: ' + CAST(ROUND(@response_time_hours, 1) AS NVARCHAR) + ' hours.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        SET @response_time_hours = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Tung Procedures created successfully.';
GO
