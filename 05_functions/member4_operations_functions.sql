-- =============================================
-- Tung: QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- HÀM (FUNCTIONS)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- HÀM 1: fn_get_available_staff
-- Đếm số nhân viên có sẵn trong bộ phận vào ngày cụ thể
-- Được gọi trong: sp_create_maintenance_request
-- =============================================
CREATE OR ALTER FUNCTION fn_get_available_staff
(
    @department_id INT,
    @target_date DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @available_count INT;
    
    SELECT @available_count = COUNT(DISTINCT e.employee_id)
    FROM EMPLOYEES e
    LEFT JOIN EMPLOYEE_SHIFTS es ON e.employee_id = es.employee_id 
        AND es.shift_date = @target_date
        AND es.status IN ('Scheduled', 'InProgress')
    WHERE e.department_id = @department_id
    AND e.is_active = 1
    AND e.is_available = 1
    AND (
        es.shift_id IS NOT NULL
        OR e.is_available = 1
    );
    
    RETURN ISNULL(@available_count, 0);
END;
GO

-- =============================================
-- HÀM 2: fn_calculate_sla_status
-- Tính trạng thái SLA dựa trên priority và thời gian
-- Được gọi trong: vw_maintenance_dashboard
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_sla_status
(
    @priority NVARCHAR(20),
    @status NVARCHAR(20),
    @created_at DATETIME,
    @completed_at DATETIME = NULL
)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @result NVARCHAR(20);
    DECLARE @hours_elapsed INT;
    
    -- Nếu đã hoàn thành
    IF @status = 'Completed'
        RETURN 'Completed';
    
    -- Tính số giờ từ lúc tạo
    SET @hours_elapsed = DATEDIFF(HOUR, @created_at, GETDATE());
    
    -- Kiểm tra SLA theo priority
    SET @result = CASE 
        -- Vi phạm SLA
        WHEN @priority = 'Critical' AND @hours_elapsed > 4 THEN 'SLA Breached'
        WHEN @priority = 'High' AND @hours_elapsed > 12 THEN 'SLA Breached'
        WHEN @priority = 'Medium' AND @hours_elapsed > 24 THEN 'SLA Breached'
        WHEN @priority = 'Low' AND @hours_elapsed > 48 THEN 'SLA Breached'
        -- Có nguy cơ
        WHEN @priority = 'Critical' AND @hours_elapsed > 2 THEN 'At Risk'
        WHEN @priority = 'High' AND @hours_elapsed > 8 THEN 'At Risk'
        WHEN @priority = 'Medium' AND @hours_elapsed > 16 THEN 'At Risk'
        -- Đúng tiến độ
        ELSE 'On Track'
    END;
    
    RETURN @result;
END;
GO

PRINT 'Tung Functions created successfully.';
GO
