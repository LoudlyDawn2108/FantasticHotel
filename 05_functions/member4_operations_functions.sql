-- Tung: FUNCTIONS (Simplified)
USE HotelManagement;
GO

-- fn_get_available_staff: Count available staff in department
CREATE OR ALTER FUNCTION fn_get_available_staff(@dept_id INT, @date DATE)
RETURNS INT AS
BEGIN
    DECLARE @cnt INT;
    SELECT @cnt = COUNT(DISTINCT e.employee_id)
    FROM EMPLOYEES e
    LEFT JOIN EMPLOYEE_SHIFTS es ON e.employee_id = es.employee_id AND es.shift_date = @date
    WHERE e.department_id = @dept_id AND e.is_active = 1 AND e.is_available = 1;
    RETURN ISNULL(@cnt, 0);
END;
GO

-- fn_calculate_sla_status: SLA status based on priority and time
CREATE OR ALTER FUNCTION fn_calculate_sla_status(@priority NVARCHAR(20), @status NVARCHAR(20), @created DATETIME)
RETURNS NVARCHAR(20) AS
BEGIN
    IF @status = 'Completed' RETURN 'Completed';
    DECLARE @hours INT = DATEDIFF(HOUR, @created, GETDATE());
    RETURN CASE 
        WHEN @priority = 'Critical' AND @hours > 4 THEN 'SLA Breached'
        WHEN @priority = 'High' AND @hours > 12 THEN 'SLA Breached'
        WHEN @priority = 'Medium' AND @hours > 24 THEN 'SLA Breached'
        WHEN @priority = 'Low' AND @hours > 48 THEN 'SLA Breached'
        WHEN @priority = 'Critical' AND @hours > 2 THEN 'At Risk'
        WHEN @priority = 'High' AND @hours > 8 THEN 'At Risk'
        ELSE 'On Track' END;
END;
GO
