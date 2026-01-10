-- =============================================
-- Tung: QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- CÁC VIEW
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_maintenance_dashboard
-- Dashboard yêu cầu bảo trì
-- Gọi Function: fn_calculate_sla_status
-- =============================================
CREATE OR ALTER VIEW vw_maintenance_dashboard
AS
SELECT 
    mr.request_id,
    rm.room_number,
    rm.floor,
    rt.type_name AS room_type,
    mr.title,
    mr.description,
    mr.priority,
    mr.status,
    mr.estimated_cost,
    mr.actual_cost,
    
    -- Thông tin nhân viên phụ trách
    ISNULL(e.first_name + ' ' + e.last_name, 'Unassigned') AS assigned_to,
    e.phone AS staff_phone,
    
    -- Thời gian
    mr.created_at,
    mr.started_at,
    mr.completed_at,
    
    -- Thời gian phản hồi (giờ)
    CASE 
        WHEN mr.completed_at IS NOT NULL
        THEN CAST(DATEDIFF(MINUTE, mr.created_at, mr.completed_at) / 60.0 AS DECIMAL(10,2))
        ELSE CAST(DATEDIFF(MINUTE, mr.created_at, GETDATE()) / 60.0 AS DECIMAL(10,2))
    END AS response_hours,
    
    -- Trạng thái SLA - GỌI FUNCTION
    dbo.fn_calculate_sla_status(mr.priority, mr.status, mr.created_at, mr.completed_at) AS sla_status,
    
    -- Trạng thái phòng
    rm.status AS current_room_status

FROM MAINTENANCE_REQUESTS mr
INNER JOIN ROOMS rm ON mr.room_id = rm.room_id
INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
LEFT JOIN EMPLOYEES e ON mr.assigned_to = e.employee_id;
GO

-- =============================================
-- VIEW 2: vw_employee_performance
-- Chỉ số nhân viên: ca làm, task hoàn thành
-- =============================================
CREATE OR ALTER VIEW vw_employee_performance
AS
SELECT 
    e.employee_id,
    e.first_name + ' ' + e.last_name AS employee_name,
    e.email,
    e.position,
    d.department_name,
    e.hire_date,
    DATEDIFF(MONTH, e.hire_date, GETDATE()) AS months_employed,
    e.is_available,
    
    -- Thống kê ca làm (30 ngày) - QUAN TRỌNG CHO HR
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
     AND es.status = 'Completed') AS shifts_completed,
    
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
     AND es.status = 'Absent') AS shifts_absent,
    
    -- Tỷ lệ đi làm - KPI QUAN TRỌNG NHẤT
    CASE 
        WHEN (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
              WHERE es.employee_id = e.employee_id 
              AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
              AND es.status IN ('Completed', 'Absent')) > 0
        THEN CAST(
            (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
             WHERE es.employee_id = e.employee_id 
             AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
             AND es.status = 'Completed') * 100.0 /
            (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
             WHERE es.employee_id = e.employee_id 
             AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
             AND es.status IN ('Completed', 'Absent'))
            AS DECIMAL(5,2))
        ELSE 100.00
    END AS attendance_rate,
    
    -- Thống kê task bảo trì
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id) AS total_tasks_assigned,
    
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status = 'Completed') AS tasks_completed,
    
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status IN ('Open', 'InProgress')) AS current_open_tasks,
    
    -- Thời gian hoàn thành trung bình (giờ)
    (SELECT AVG(CAST(DATEDIFF(MINUTE, mr.created_at, mr.completed_at) AS DECIMAL(10,2)) / 60)
     FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status = 'Completed'
     AND mr.completed_at IS NOT NULL) AS avg_completion_hours,
    
    -- Xếp hạng hiệu suất
    CASE 
        WHEN d.department_name = 'Maintenance' THEN
            CASE 
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 20 THEN 'Excellent'
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 10 THEN 'Good'
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 5 THEN 'Average'
                ELSE 'New'
            END
        ELSE 'N/A'
    END AS performance_rating

FROM EMPLOYEES e
INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
WHERE e.is_active = 1;
GO

PRINT 'Tung Views created successfully.';
GO
