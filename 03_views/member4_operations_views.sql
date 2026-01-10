-- Tung: VIEWS (Simplified)
USE HotelManagement;
GO

-- vw_maintenance_dashboard: Maintenance request overview
CREATE OR ALTER VIEW vw_maintenance_dashboard AS
SELECT mr.request_id, rm.room_number, mr.title, mr.priority, mr.status,
    e.first_name + ' ' + e.last_name AS assigned_to, mr.created_at,
    DATEDIFF(HOUR, mr.created_at, ISNULL(mr.completed_at, GETDATE())) AS hours_elapsed,
    dbo.fn_calculate_sla_status(mr.priority, mr.status, mr.created_at) AS sla_status
FROM MAINTENANCE_REQUESTS mr
JOIN ROOMS rm ON mr.room_id = rm.room_id
LEFT JOIN EMPLOYEES e ON mr.assigned_to = e.employee_id;
GO

-- vw_employee_performance: Staff performance metrics
CREATE OR ALTER VIEW vw_employee_performance AS
SELECT e.employee_id, e.first_name + ' ' + e.last_name AS name, d.department_name,
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS WHERE employee_id = e.employee_id) AS total_shifts,
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS WHERE employee_id = e.employee_id AND status = 'Completed') AS completed,
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS WHERE assigned_to = e.employee_id AND status = 'Completed') AS tasks_done
FROM EMPLOYEES e JOIN DEPARTMENTS d ON e.department_id = d.department_id WHERE e.is_active = 1;
GO
