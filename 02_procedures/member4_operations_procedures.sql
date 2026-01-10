-- Tung: OPERATIONS PROCEDURES (Simplified)
USE HotelManagement;
GO

-- sp_create_maintenance_request: Create request, auto-assign staff
CREATE OR ALTER PROCEDURE sp_create_maintenance_request
    @room_id INT, @title NVARCHAR(200), @priority NVARCHAR(20) = 'Medium',
    @req_id INT OUTPUT, @assigned NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @room_num NVARCHAR(10), @status NVARCHAR(20), @emp_id INT, @dept_id INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate room
        SELECT @room_num = room_number, @status = status FROM ROOMS WHERE room_id = @room_id;
        IF @room_num IS NULL BEGIN ROLLBACK; RETURN -1; END
        
        -- Get maintenance dept
        SELECT @dept_id = department_id FROM DEPARTMENTS WHERE department_name = 'Maintenance';
        
        -- Find employee with least open requests
        SELECT TOP 1 @emp_id = e.employee_id
        FROM EMPLOYEES e
        LEFT JOIN (SELECT assigned_to, COUNT(*) AS cnt FROM MAINTENANCE_REQUESTS 
            WHERE status IN ('Open','InProgress') GROUP BY assigned_to) mr ON e.employee_id = mr.assigned_to
        WHERE e.department_id = @dept_id AND e.is_active = 1 AND e.is_available = 1
        ORDER BY ISNULL(mr.cnt, 0), e.hire_date;
        
        SELECT @assigned = ISNULL(first_name + ' ' + last_name, 'Unassigned') 
        FROM EMPLOYEES WHERE employee_id = @emp_id;
        IF @assigned IS NULL SET @assigned = 'Unassigned';
        
        -- Create request
        INSERT INTO MAINTENANCE_REQUESTS (room_id, assigned_to, title, priority, status)
        VALUES (@room_id, @emp_id, @title, @priority, 'Open');
        SET @req_id = SCOPE_IDENTITY();
        
        -- High/Critical: mark room as maintenance
        IF @priority IN ('Critical','High') AND @status = 'Available'
            UPDATE ROOMS SET status = 'Maintenance' WHERE room_id = @room_id;
        
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @req_id = NULL; SET @assigned = NULL;
        RETURN -1;
    END CATCH
END;
GO

-- sp_complete_maintenance: Complete request, update room status
CREATE OR ALTER PROCEDURE sp_complete_maintenance
    @req_id INT, @cost DECIMAL(10,2) = NULL,
    @hours DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @status NVARCHAR(20), @room_id INT, @created DATETIME, @has_res BIT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        SELECT @status = status, @room_id = room_id, @created = created_at
        FROM MAINTENANCE_REQUESTS WHERE request_id = @req_id;
        
        IF @status IN ('Completed','Cancelled') BEGIN ROLLBACK; RETURN -1; END
        
        -- Calculate response time
        SET @hours = CAST(DATEDIFF(MINUTE, @created, GETDATE()) AS DECIMAL(10,2)) / 60;
        
        -- Complete request
        UPDATE MAINTENANCE_REQUESTS SET status = 'Completed', actual_cost = @cost,
            completed_at = GETDATE() WHERE request_id = @req_id;
        
        -- Check active reservation
        IF EXISTS (SELECT 1 FROM RESERVATIONS WHERE room_id = @room_id 
            AND status IN ('Confirmed','CheckedIn') AND GETDATE() BETWEEN check_in_date AND check_out_date)
            SET @has_res = 1;
        
        -- Update room
        UPDATE ROOMS SET status = CASE WHEN @has_res = 1 THEN 'Occupied' ELSE 'Available' END
        WHERE room_id = @room_id AND status = 'Maintenance';
        
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @hours = NULL;
        RETURN -1;
    END CATCH
END;
GO
