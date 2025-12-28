-- =============================================
-- MEMBER 4: OPERATIONS & HR MANAGEMENT
-- VIEWS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_maintenance_dashboard
-- Active requests, response times, staff workload
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
    
    -- Staff assignment
    ISNULL(e.first_name + ' ' + e.last_name, 'Unassigned') AS assigned_to,
    e.phone AS staff_phone,
    
    -- Timestamps
    mr.created_at,
    mr.started_at,
    mr.completed_at,
    
    -- Time metrics
    CASE 
        WHEN mr.status = 'Completed' AND mr.completed_at IS NOT NULL
        THEN CAST(DATEDIFF(MINUTE, mr.created_at, mr.completed_at) / 60.0 AS DECIMAL(10,2))
        ELSE CAST(DATEDIFF(MINUTE, mr.created_at, GETDATE()) / 60.0 AS DECIMAL(10,2))
    END AS total_response_hours,
    
    CASE 
        WHEN mr.started_at IS NOT NULL AND mr.completed_at IS NOT NULL
        THEN CAST(DATEDIFF(MINUTE, mr.started_at, mr.completed_at) / 60.0 AS DECIMAL(10,2))
        WHEN mr.started_at IS NOT NULL
        THEN CAST(DATEDIFF(MINUTE, mr.started_at, GETDATE()) / 60.0 AS DECIMAL(10,2))
        ELSE NULL
    END AS work_duration_hours,
    
    -- SLA Status (based on priority)
    CASE 
        WHEN mr.status = 'Completed' THEN 'Completed'
        WHEN mr.priority = 'Critical' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 4 THEN 'SLA Breached'
        WHEN mr.priority = 'High' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 12 THEN 'SLA Breached'
        WHEN mr.priority = 'Medium' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 24 THEN 'SLA Breached'
        WHEN mr.priority = 'Low' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 48 THEN 'SLA Breached'
        WHEN mr.priority = 'Critical' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 2 THEN 'At Risk'
        WHEN mr.priority = 'High' AND DATEDIFF(HOUR, mr.created_at, GETDATE()) > 8 THEN 'At Risk'
        ELSE 'On Track'
    END AS sla_status,
    
    -- Room impact
    rm.status AS current_room_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM RESERVATIONS r 
            WHERE r.room_id = mr.room_id 
            AND r.status IN ('Confirmed', 'CheckedIn')
            AND r.check_in_date <= DATEADD(DAY, 1, GETDATE())
        )
        THEN 'High Impact - Upcoming/Active Booking'
        ELSE 'Low Impact'
    END AS booking_impact

FROM MAINTENANCE_REQUESTS mr
INNER JOIN ROOMS rm ON mr.room_id = rm.room_id
INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
LEFT JOIN EMPLOYEES e ON mr.assigned_to = e.employee_id;
GO

-- =============================================
-- VIEW 2: vw_employee_performance
-- Employee metrics: shifts worked, tasks completed,
-- workload distribution
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
    
    -- Shift statistics (last 30 days)
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
     AND es.status IN ('Scheduled', 'Completed')) AS shifts_last_30_days,
    
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
     AND es.status = 'Completed') AS shifts_completed,
    
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date >= DATEADD(DAY, -30, GETDATE())
     AND es.status = 'Absent') AS shifts_absent,
    
    -- Attendance rate
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
    
    -- Maintenance tasks (for maintenance staff)
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id) AS total_tasks_assigned,
    
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status = 'Completed') AS tasks_completed,
    
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status IN ('Open', 'InProgress')) AS current_open_tasks,
    
    -- Average completion time
    (SELECT AVG(CAST(DATEDIFF(MINUTE, mr.created_at, mr.completed_at) AS DECIMAL(10,2)) / 60)
     FROM MAINTENANCE_REQUESTS mr 
     WHERE mr.assigned_to = e.employee_id 
     AND mr.status = 'Completed'
     AND mr.completed_at IS NOT NULL) AS avg_completion_hours,
    
    -- Performance rating (calculated metric)
    CASE 
        WHEN d.department_name = 'Maintenance' THEN
            CASE 
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 20
                     AND (SELECT AVG(CAST(DATEDIFF(HOUR, mr.created_at, mr.completed_at) AS DECIMAL)) 
                          FROM MAINTENANCE_REQUESTS mr 
                          WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') < 8 THEN 'Excellent'
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 10 THEN 'Good'
                WHEN (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                      WHERE mr.assigned_to = e.employee_id AND mr.status = 'Completed') >= 5 THEN 'Average'
                ELSE 'New'
            END
        ELSE 'N/A'
    END AS performance_rating,
    
    -- Today's shift
    (SELECT TOP 1 CONCAT(es.start_time, ' - ', es.end_time)
     FROM EMPLOYEE_SHIFTS es 
     WHERE es.employee_id = e.employee_id 
     AND es.shift_date = CAST(GETDATE() AS DATE)
     ORDER BY es.start_time) AS today_shift

FROM EMPLOYEES e
INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
WHERE e.is_active = 1;
GO

PRINT 'Member 4 Views created successfully.';
GO
