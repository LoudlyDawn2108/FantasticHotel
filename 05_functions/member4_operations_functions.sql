-- =============================================
-- Tung: QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- HÀM (FUNCTIONS)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- HÀM 1: fn_calculate_room_turnaround_time
-- Tính thời gian trung bình chuẩn bị phòng cho khách tiếp theo
-- (từ checkout đến available)
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_room_turnaround_time
(
    @room_id INT = NULL,  -- Nếu NULL, tính cho tất cả phòng
    @days_back INT = 30   -- Số ngày lùi lại
)
RETURNS TABLE
AS
RETURN
(
    WITH TurnaroundData AS (
        SELECT 
            rsh1.room_id,
            rm.room_number,
            rsh1.changed_at AS cleaning_start,
            rsh2.changed_at AS cleaning_end,
            DATEDIFF(MINUTE, rsh1.changed_at, rsh2.changed_at) AS turnaround_minutes
        FROM ROOM_STATUS_HISTORY rsh1
        INNER JOIN ROOMS rm ON rsh1.room_id = rm.room_id
        INNER JOIN ROOM_STATUS_HISTORY rsh2 ON rsh1.room_id = rsh2.room_id
            AND rsh2.history_id = (
                SELECT MIN(history_id) 
                FROM ROOM_STATUS_HISTORY 
                WHERE room_id = rsh1.room_id 
                AND history_id > rsh1.history_id
                AND new_status = 'Available'
            )
        WHERE rsh1.new_status = 'Cleaning'
        AND rsh1.changed_at >= DATEADD(DAY, -@days_back, GETDATE())
        AND (@room_id IS NULL OR rsh1.room_id = @room_id)
    )
    SELECT 
        ISNULL(room_id, 0) AS room_id,
        ISNULL(room_number, 'All Rooms') AS room_number,
        COUNT(*) AS turnaround_count,
        CAST(AVG(turnaround_minutes) AS DECIMAL(10,2)) AS avg_turnaround_minutes,
        CAST(AVG(turnaround_minutes) / 60.0 AS DECIMAL(10,2)) AS avg_turnaround_hours,
        CAST(MIN(turnaround_minutes) AS INT) AS min_turnaround_minutes,
        CAST(MAX(turnaround_minutes) AS INT) AS max_turnaround_minutes,
        CASE 
            WHEN AVG(turnaround_minutes) <= 30 THEN 'Excellent'
            WHEN AVG(turnaround_minutes) <= 45 THEN 'Good'
            WHEN AVG(turnaround_minutes) <= 60 THEN 'Average'
            ELSE 'Needs Improvement'
        END AS performance_rating
    FROM TurnaroundData
    GROUP BY room_id, room_number
    
    UNION ALL
    
    -- Tổng kết chung
    SELECT 
        0 AS room_id,
        'OVERALL AVERAGE' AS room_number,
        COUNT(*) AS turnaround_count,
        CAST(AVG(turnaround_minutes) AS DECIMAL(10,2)) AS avg_turnaround_minutes,
        CAST(AVG(turnaround_minutes) / 60.0 AS DECIMAL(10,2)) AS avg_turnaround_hours,
        CAST(MIN(turnaround_minutes) AS INT) AS min_turnaround_minutes,
        CAST(MAX(turnaround_minutes) AS INT) AS max_turnaround_minutes,
        CASE 
            WHEN AVG(turnaround_minutes) <= 30 THEN 'Excellent'
            WHEN AVG(turnaround_minutes) <= 45 THEN 'Good'
            WHEN AVG(turnaround_minutes) <= 60 THEN 'Average'
            ELSE 'Needs Improvement'
        END AS performance_rating
    FROM TurnaroundData
    WHERE @room_id IS NULL  -- Chỉ hiển thị tổng kết khi không lọc theo phòng
);
GO

-- =============================================
-- HÀM 2: fn_get_available_staff
-- Đếm số nhân viên có sẵn trong bộ phận vào ngày cụ thể
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
        -- Có ca làm hôm nay
        es.shift_id IS NOT NULL
        OR
        -- Hoặc đang rảnh
        e.is_available = 1
    );
    
    RETURN ISNULL(@available_count, 0);
END;
GO

-- =============================================
-- HÀM 3: fn_get_maintenance_statistics
-- Thống kê bảo trì toàn diện dưới dạng bảng
-- =============================================
CREATE OR ALTER FUNCTION fn_get_maintenance_statistics
(
    @days_back INT = 30
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        -- Tổng số yêu cầu
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS total_requests,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS completed_requests,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE status IN ('Open', 'InProgress')
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS pending_requests,
        
        -- Theo mức độ ưu tiên
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE priority = 'Critical'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS critical_count,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE priority = 'High'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS high_count,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE priority = 'Medium'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS medium_count,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE priority = 'Low'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS low_count,
        
        -- Chỉ số thời gian
        (SELECT AVG(CAST(DATEDIFF(MINUTE, created_at, completed_at) AS DECIMAL) / 60)
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed' AND completed_at IS NOT NULL
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS avg_resolution_hours,
        
        -- Chỉ số chi phí
        (SELECT SUM(ISNULL(actual_cost, 0)) 
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS total_actual_cost,
        
        (SELECT AVG(ISNULL(actual_cost, 0)) 
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed' AND actual_cost IS NOT NULL
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS avg_cost_per_request,
        
        -- Hiệu suất SLA
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr
         WHERE mr.status = 'Completed'
         AND mr.created_at >= DATEADD(DAY, -@days_back, GETDATE())
         AND (
             (mr.priority = 'Critical' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 4) OR
             (mr.priority = 'High' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 12) OR
             (mr.priority = 'Medium' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 24) OR
             (mr.priority = 'Low' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 48)
         )) AS sla_met_count,
        
        -- Tỷ lệ hoàn thành
        CASE 
            WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
                  WHERE created_at >= DATEADD(DAY, -@days_back, GETDATE())) > 0
            THEN CAST(
                (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
                 WHERE status = 'Completed'
                 AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) * 100.0 /
                (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
                 WHERE created_at >= DATEADD(DAY, -@days_back, GETDATE()))
                AS DECIMAL(5,2))
            ELSE 0
        END AS completion_rate_percent
);
GO

PRINT 'Tung Functions created successfully.';
GO
