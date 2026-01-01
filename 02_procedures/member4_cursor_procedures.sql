-- =============================================
-- Tung: OPERATIONS & HR MANAGEMENT
-- CURSOR PROCEDURES (2 CURSORS)
-- =============================================
-- Business Process: Complete Operations & HR Lifecycle
-- These cursors work with sp_create_maintenance_request, sp_complete_maintenance,
-- vw_maintenance_dashboard, vw_employee_performance, trg_room_status_history,
-- trg_high_priority_maintenance, fn_calculate_room_turnaround_time, fn_get_available_staff
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: sp_auto_assign_maintenance_tasks
-- Automatically assigns unassigned maintenance tasks to available staff
-- Uses CURSOR to iterate through open requests and balance workload
-- =============================================
CREATE OR ALTER PROCEDURE sp_auto_assign_maintenance_tasks
    @assigned_count INT OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @request_id INT;
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @title NVARCHAR(200);
    DECLARE @priority NVARCHAR(20);
    DECLARE @created_at DATETIME;
    DECLARE @hours_waiting DECIMAL(10,2);
    
    DECLARE @employee_id INT;
    DECLARE @employee_name NVARCHAR(100);
    DECLARE @current_workload INT;
    DECLARE @maintenance_dept_id INT;
    
    SET @assigned_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get maintenance department ID
        SELECT @maintenance_dept_id = department_id
        FROM DEPARTMENTS
        WHERE department_name = 'Maintenance';
        
        -- CURSOR: Iterate through unassigned maintenance requests (priority order)
        DECLARE request_cursor CURSOR FOR
            SELECT 
                mr.request_id,
                mr.room_id,
                rm.room_number,
                mr.title,
                mr.priority,
                mr.created_at,
                CAST(DATEDIFF(MINUTE, mr.created_at, GETDATE()) AS DECIMAL(10,2)) / 60 AS hours_waiting
            FROM MAINTENANCE_REQUESTS mr
            INNER JOIN ROOMS rm ON mr.room_id = rm.room_id
            WHERE mr.assigned_to IS NULL
            AND mr.status = 'Open'
            ORDER BY 
                CASE mr.priority 
                    WHEN 'Critical' THEN 1 
                    WHEN 'High' THEN 2 
                    WHEN 'Medium' THEN 3 
                    WHEN 'Low' THEN 4 
                END,
                mr.created_at ASC;  -- Oldest first within same priority
        
        OPEN request_cursor;
        FETCH NEXT FROM request_cursor INTO 
            @request_id, @room_id, @room_number, @title, @priority, @created_at, @hours_waiting;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Find available staff with lowest workload using sub-cursor
            SET @employee_id = NULL;
            
            -- NESTED CURSOR: Find best available employee
            DECLARE staff_cursor CURSOR FOR
                SELECT 
                    e.employee_id,
                    e.first_name + ' ' + e.last_name AS employee_name,
                    ISNULL((
                        SELECT COUNT(*) 
                        FROM MAINTENANCE_REQUESTS mr 
                        WHERE mr.assigned_to = e.employee_id 
                        AND mr.status IN ('Open', 'InProgress')
                    ), 0) AS current_workload
                FROM EMPLOYEES e
                WHERE e.department_id = @maintenance_dept_id
                AND e.is_active = 1
                AND e.is_available = 1
                -- Check if employee has a shift today
                AND EXISTS (
                    SELECT 1 FROM EMPLOYEE_SHIFTS es 
                    WHERE es.employee_id = e.employee_id 
                    AND es.shift_date = CAST(GETDATE() AS DATE)
                    AND es.status IN ('Scheduled', 'InProgress')
                )
                ORDER BY 
                    ISNULL((
                        SELECT COUNT(*) 
                        FROM MAINTENANCE_REQUESTS mr 
                        WHERE mr.assigned_to = e.employee_id 
                        AND mr.status IN ('Open', 'InProgress')
                    ), 0) ASC,  -- Lowest workload first
                    e.hire_date ASC;  -- Most experienced if tie
            
            OPEN staff_cursor;
            FETCH NEXT FROM staff_cursor INTO @employee_id, @employee_name, @current_workload;
            
            -- Only assign if workload is manageable (less than 5 open tasks)
            IF @@FETCH_STATUS = 0 AND @current_workload < 5
            BEGIN
                -- Assign the task
                UPDATE MAINTENANCE_REQUESTS
                SET 
                    assigned_to = @employee_id,
                    status = 'Open',  -- Keep as open, staff will start it
                    started_at = NULL
                WHERE request_id = @request_id;
                
                -- Create notification for assigned staff
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type, recipient_id
                )
                VALUES (
                    'TaskAssignment',
                    'New Task Assigned: ' + @priority + ' Priority',
                    'Task: ' + @title + ' | Room: ' + @room_number +
                    ' | Waiting: ' + CAST(ROUND(@hours_waiting, 1) AS NVARCHAR) + ' hours',
                    'MAINTENANCE_REQUESTS',
                    @request_id,
                    'Employee',
                    @employee_id
                );
                
                SET @assigned_count = @assigned_count + 1;
            END
            
            CLOSE staff_cursor;
            DEALLOCATE staff_cursor;
            
            FETCH NEXT FROM request_cursor INTO 
                @request_id, @room_id, @room_number, @title, @priority, @created_at, @hours_waiting;
        END
        
        CLOSE request_cursor;
        DEALLOCATE request_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Auto-assignment completed. ' + 
                       CAST(@assigned_count AS NVARCHAR) + ' tasks assigned to available staff.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'request_cursor') >= 0
        BEGIN
            CLOSE request_cursor;
            DEALLOCATE request_cursor;
        END
        
        IF CURSOR_STATUS('local', 'staff_cursor') >= 0
        BEGIN
            CLOSE staff_cursor;
            DEALLOCATE staff_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- CURSOR 2: sp_generate_employee_shift_schedule
-- Generates weekly shift schedule for all departments
-- Uses CURSOR to create and assign shifts automatically
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_employee_shift_schedule
    @week_start_date DATE,
    @schedule_count INT OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @employee_id INT;
    DECLARE @employee_name NVARCHAR(100);
    DECLARE @department_id INT;
    DECLARE @department_name NVARCHAR(100);
    DECLARE @position NVARCHAR(100);
    
    DECLARE @current_date DATE;
    DECLARE @day_counter INT;
    DECLARE @shift_start TIME;
    DECLARE @shift_end TIME;
    
    SET @schedule_count = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Ensure week_start_date is a Monday
        SET @week_start_date = DATEADD(DAY, -(DATEPART(WEEKDAY, @week_start_date) - 2), @week_start_date);
        IF DATEPART(WEEKDAY, @week_start_date) = 1  -- If it became Sunday
            SET @week_start_date = DATEADD(DAY, 1, @week_start_date);
        
        -- Delete existing schedules for this week (if regenerating)
        DELETE FROM EMPLOYEE_SHIFTS
        WHERE shift_date BETWEEN @week_start_date AND DATEADD(DAY, 6, @week_start_date)
        AND status = 'Scheduled';  -- Only delete scheduled, not completed
        
        -- CURSOR: Iterate through all active employees
        DECLARE employee_cursor CURSOR FOR
            SELECT 
                e.employee_id,
                e.first_name + ' ' + e.last_name AS employee_name,
                e.department_id,
                d.department_name,
                e.position
            FROM EMPLOYEES e
            INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
            WHERE e.is_active = 1
            ORDER BY d.department_name, e.employee_id;
        
        OPEN employee_cursor;
        FETCH NEXT FROM employee_cursor INTO 
            @employee_id, @employee_name, @department_id, @department_name, @position;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Assign shifts for 5 days (typical work week)
            SET @day_counter = 0;
            
            WHILE @day_counter < 7
            BEGIN
                SET @current_date = DATEADD(DAY, @day_counter, @week_start_date);
                
                -- Determine shift times based on department and weekday/weekend
                -- Give employees 2 days off per week (based on employee_id to vary)
                IF @day_counter NOT IN ((@employee_id % 7), ((@employee_id + 1) % 7))
                BEGIN
                    -- Determine shift based on department
                    SELECT @shift_start = CASE @department_name
                        WHEN 'Front Desk' THEN 
                            CASE WHEN @employee_id % 3 = 0 THEN '07:00' 
                                 WHEN @employee_id % 3 = 1 THEN '15:00' 
                                 ELSE '23:00' END
                        WHEN 'Housekeeping' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '06:00' ELSE '14:00' END
                        WHEN 'Food & Beverage' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '06:00' ELSE '14:00' END
                        WHEN 'Maintenance' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '08:00' ELSE '16:00' END
                        WHEN 'Security' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '06:00' ELSE '18:00' END
                        ELSE '09:00'
                    END;
                    
                    SELECT @shift_end = CASE @department_name
                        WHEN 'Front Desk' THEN 
                            CASE WHEN @employee_id % 3 = 0 THEN '15:00' 
                                 WHEN @employee_id % 3 = 1 THEN '23:00' 
                                 ELSE '07:00' END
                        WHEN 'Housekeeping' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '14:00' ELSE '22:00' END
                        WHEN 'Food & Beverage' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '14:00' ELSE '22:00' END
                        WHEN 'Maintenance' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '16:00' ELSE '00:00' END
                        WHEN 'Security' THEN 
                            CASE WHEN @employee_id % 2 = 0 THEN '18:00' ELSE '06:00' END
                        ELSE '17:00'
                    END;
                    
                    -- Insert shift
                    INSERT INTO EMPLOYEE_SHIFTS (
                        employee_id, shift_date, start_time, end_time, status
                    )
                    VALUES (
                        @employee_id, @current_date, @shift_start, @shift_end, 'Scheduled'
                    );
                    
                    SET @schedule_count = @schedule_count + 1;
                END
                
                SET @day_counter = @day_counter + 1;
            END
            
            FETCH NEXT FROM employee_cursor INTO 
                @employee_id, @employee_name, @department_id, @department_name, @position;
        END
        
        CLOSE employee_cursor;
        DEALLOCATE employee_cursor;
        
        -- Create summary notification
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, recipient_type
        )
        VALUES (
            'ScheduleGenerated',
            'Weekly Schedule Generated',
            'Schedule for week of ' + FORMAT(@week_start_date, 'MMM dd, yyyy') + 
            ' has been generated. Total ' + CAST(@schedule_count AS NVARCHAR) + ' shifts created.',
            'EMPLOYEE_SHIFTS',
            'Management'
        );
        
        COMMIT TRANSACTION;
        
        SET @message = 'Schedule generated successfully for week of ' + 
                       FORMAT(@week_start_date, 'MMM dd, yyyy') + '. ' +
                       CAST(@schedule_count AS NVARCHAR) + ' shifts created.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'employee_cursor') >= 0
        BEGIN
            CLOSE employee_cursor;
            DEALLOCATE employee_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Tung Cursor Procedures created successfully.';
GO
