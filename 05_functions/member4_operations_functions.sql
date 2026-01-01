-- =============================================
-- Tung: OPERATIONS & HR MANAGEMENT
-- FUNCTIONS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION 1: fn_calculate_room_turnaround_time
-- Returns average time to prepare room for next
-- guest (from checkout to available)
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_room_turnaround_time
(
    @room_id INT = NULL,  -- If NULL, calculate for all rooms
    @days_back INT = 30   -- Look back period in days
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
    
    -- Overall summary
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
    WHERE @room_id IS NULL  -- Only show overall when not filtering by room
);
GO

-- =============================================
-- FUNCTION 2: fn_get_available_staff
-- Returns count of available staff for a
-- department on a given date
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
        -- Either has a shift scheduled for today
        es.shift_id IS NOT NULL
        OR
        -- Or is simply marked as available (for flexibility)
        e.is_available = 1
    );
    
    RETURN ISNULL(@available_count, 0);
END;
GO

-- =============================================
-- FUNCTION 3: fn_get_maintenance_statistics
-- Returns comprehensive maintenance statistics
-- as a table
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
        -- Overall counts
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS total_requests,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS completed_requests,
        
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS 
         WHERE status IN ('Open', 'InProgress')
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS pending_requests,
        
        -- By Priority
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
        
        -- Time metrics
        (SELECT AVG(CAST(DATEDIFF(MINUTE, created_at, completed_at) AS DECIMAL) / 60)
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed' AND completed_at IS NOT NULL
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS avg_resolution_hours,
        
        -- Cost metrics
        (SELECT SUM(ISNULL(actual_cost, 0)) 
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed'
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS total_actual_cost,
        
        (SELECT AVG(ISNULL(actual_cost, 0)) 
         FROM MAINTENANCE_REQUESTS 
         WHERE status = 'Completed' AND actual_cost IS NOT NULL
         AND created_at >= DATEADD(DAY, -@days_back, GETDATE())) AS avg_cost_per_request,
        
        -- SLA Performance
        (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr
         WHERE mr.status = 'Completed'
         AND mr.created_at >= DATEADD(DAY, -@days_back, GETDATE())
         AND (
             (mr.priority = 'Critical' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 4) OR
             (mr.priority = 'High' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 12) OR
             (mr.priority = 'Medium' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 24) OR
             (mr.priority = 'Low' AND DATEDIFF(HOUR, mr.created_at, mr.completed_at) <= 48)
         )) AS sla_met_count,
        
        -- Completion rate
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
