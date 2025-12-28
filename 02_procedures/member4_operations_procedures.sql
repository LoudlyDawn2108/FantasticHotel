-- =============================================
-- MEMBER 4: OPERATIONS & HR MANAGEMENT
-- STORED PROCEDURES
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- PROCEDURE 1: sp_create_maintenance_request
-- Creates maintenance request with priority
-- assignment and automatic staff allocation
-- =============================================
CREATE OR ALTER PROCEDURE sp_create_maintenance_request
    @room_id INT,
    @title NVARCHAR(200),
    @description NVARCHAR(1000) = NULL,
    @priority NVARCHAR(20) = 'Medium',
    @estimated_cost DECIMAL(10,2) = NULL,
    @created_by INT = NULL,
    @request_id INT OUTPUT,
    @assigned_employee NVARCHAR(100) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @room_number NVARCHAR(10);
    DECLARE @room_status NVARCHAR(20);
    DECLARE @assigned_to INT;
    DECLARE @maintenance_dept_id INT;
    DECLARE @available_staff_count INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate room exists
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
        
        -- Validate priority
        IF @priority NOT IN ('Low', 'Medium', 'High', 'Critical')
        BEGIN
            SET @message = 'Error: Invalid priority. Accepted values: Low, Medium, High, Critical.';
            SET @request_id = NULL;
            SET @assigned_employee = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Get Maintenance department ID
        SELECT @maintenance_dept_id = department_id
        FROM DEPARTMENTS
        WHERE department_name = 'Maintenance';
        
        -- Check available staff count
        SET @available_staff_count = dbo.fn_get_available_staff(@maintenance_dept_id, CAST(GETDATE() AS DATE));
        
        -- Find available maintenance staff (least workload)
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
        
        -- If no staff available, still create request but without assignment
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
        
        -- Create maintenance request
        INSERT INTO MAINTENANCE_REQUESTS (
            room_id, assigned_to, title, description,
            priority, status, estimated_cost, created_by
        )
        VALUES (
            @room_id, @assigned_to, @title, @description,
            @priority, 'Open', @estimated_cost, @created_by
        );
        
        SET @request_id = SCOPE_IDENTITY();
        
        -- If Critical or High priority, update room status to Maintenance
        IF @priority IN ('Critical', 'High') AND @room_status = 'Available'
        BEGIN
            UPDATE ROOMS
            SET status = 'Maintenance', updated_at = GETDATE()
            WHERE room_id = @room_id;
        END
        
        -- Create notification for assigned staff
        IF @assigned_to IS NOT NULL
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type, recipient_id
            )
            VALUES (
                'MaintenanceAssignment',
                'New Maintenance Request Assigned',
                'You have been assigned to: ' + @title + ' (Room ' + @room_number + '). Priority: ' + @priority,
                'MAINTENANCE_REQUESTS',
                @request_id,
                'Employee',
                @assigned_to
            );
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
-- PROCEDURE 2: sp_complete_maintenance
-- Completes maintenance request, updates room
-- status, and calculates response metrics
-- =============================================
CREATE OR ALTER PROCEDURE sp_complete_maintenance
    @request_id INT,
    @actual_cost DECIMAL(10,2) = NULL,
    @completion_notes NVARCHAR(500) = NULL,
    @completed_by INT = NULL,
    @response_time_hours DECIMAL(10,2) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @current_status NVARCHAR(20);
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @priority NVARCHAR(20);
    DECLARE @created_at DATETIME;
    DECLARE @started_at DATETIME;
    DECLARE @assigned_to INT;
    DECLARE @has_active_reservation BIT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Get maintenance request details
        SELECT 
            @current_status = status,
            @room_id = room_id,
            @priority = priority,
            @created_at = created_at,
            @started_at = started_at,
            @assigned_to = assigned_to
        FROM MAINTENANCE_REQUESTS
        WHERE request_id = @request_id;
        
        -- Validate request exists
        IF @current_status IS NULL
        BEGIN
            SET @message = 'Error: Maintenance request not found.';
            SET @response_time_hours = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Check if already completed or cancelled
        IF @current_status IN ('Completed', 'Cancelled')
        BEGIN
            SET @message = 'Error: Request is already ' + @current_status + '.';
            SET @response_time_hours = NULL;
            ROLLBACK TRANSACTION;
            RETURN -1;
        END
        
        -- Get room number
        SELECT @room_number = room_number FROM ROOMS WHERE room_id = @room_id;
        
        -- Calculate response time (from creation to now)
        SET @response_time_hours = CAST(DATEDIFF(MINUTE, @created_at, GETDATE()) AS DECIMAL(10,2)) / 60;
        
        -- Update request to completed
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
        
        -- Check if room has active reservation
        IF EXISTS (
            SELECT 1 FROM RESERVATIONS
            WHERE room_id = @room_id
            AND status IN ('Confirmed', 'CheckedIn')
            AND GETDATE() BETWEEN check_in_date AND check_out_date
        )
        BEGIN
            SET @has_active_reservation = 1;
        END
        
        -- Update room status based on whether there's an active reservation
        UPDATE ROOMS
        SET 
            status = CASE 
                WHEN @has_active_reservation = 1 THEN 'Occupied'
                ELSE 'Available'
            END,
            updated_at = GETDATE()
        WHERE room_id = @room_id
        AND status = 'Maintenance';
        
        -- Create completion notification
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, related_id, recipient_type
        )
        VALUES (
            'MaintenanceComplete',
            'Maintenance Completed',
            'Maintenance request #' + CAST(@request_id AS NVARCHAR) + ' for Room ' + @room_number + 
            ' has been completed. Response time: ' + CAST(ROUND(@response_time_hours, 1) AS NVARCHAR) + ' hours.' +
            CASE 
                WHEN @actual_cost IS NOT NULL THEN ' Cost: $' + CAST(@actual_cost AS NVARCHAR)
                ELSE ''
            END,
            'MAINTENANCE_REQUESTS',
            @request_id,
            'Front Desk'
        );
        
        -- Update employee performance (mark as available for new tasks if needed)
        IF @assigned_to IS NOT NULL
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type, recipient_id
            )
            VALUES (
                'TaskComplete',
                'Task Completed Successfully',
                'Maintenance request #' + CAST(@request_id AS NVARCHAR) + ' has been marked as complete. Good job!',
                'MAINTENANCE_REQUESTS',
                @request_id,
                'Employee',
                @assigned_to
            );
        END
        
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

PRINT 'Member 4 Procedures created successfully.';
GO
