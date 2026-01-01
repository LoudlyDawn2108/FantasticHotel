-- =============================================
-- Tung: OPERATIONS & HR MANAGEMENT
-- TRIGGERS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TRIGGER 1: trg_room_status_history
-- Logs all room status changes to ROOM_STATUS_HISTORY
-- =============================================
CREATE OR ALTER TRIGGER trg_room_status_history
ON ROOMS
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Only proceed if status was updated
    IF NOT UPDATE(status)
        RETURN;
    
    DECLARE @room_id INT;
    DECLARE @old_status NVARCHAR(20);
    DECLARE @new_status NVARCHAR(20);
    DECLARE @room_number NVARCHAR(10);
    
    -- Insert history record for each status change
    INSERT INTO ROOM_STATUS_HISTORY (
        room_id, old_status, new_status, changed_at, reason
    )
    SELECT 
        i.room_id,
        d.status,
        i.status,
        GETDATE(),
        CASE 
            WHEN i.status = 'Occupied' THEN 'Guest checked in'
            WHEN i.status = 'Cleaning' THEN 'Guest checked out, needs cleaning'
            WHEN i.status = 'Available' AND d.status = 'Cleaning' THEN 'Room cleaned and ready'
            WHEN i.status = 'Available' AND d.status = 'Maintenance' THEN 'Maintenance completed'
            WHEN i.status = 'Maintenance' THEN 'Maintenance required'
            WHEN i.status = 'Reserved' THEN 'Reservation confirmed for today'
            ELSE 'Status changed'
        END
    FROM inserted i
    INNER JOIN deleted d ON i.room_id = d.room_id
    WHERE i.status <> d.status;
    
    -- Create notification for significant status changes
    DECLARE status_cursor CURSOR FOR
        SELECT i.room_id, d.status, i.status, i.room_number
        FROM inserted i
        INNER JOIN deleted d ON i.room_id = d.room_id
        WHERE i.status <> d.status;
    
    OPEN status_cursor;
    FETCH NEXT FROM status_cursor INTO @room_id, @old_status, @new_status, @room_number;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Notify housekeeping when room needs cleaning
        IF @new_status = 'Cleaning'
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'RoomCleaning',
                'Room Ready for Cleaning',
                'Room ' + @room_number + ' is now ready for cleaning.',
                'ROOMS',
                @room_id,
                'Housekeeping'
            );
        END
        
        -- Notify front desk when room becomes available
        IF @new_status = 'Available' AND @old_status IN ('Cleaning', 'Maintenance')
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'RoomAvailable',
                'Room Now Available',
                'Room ' + @room_number + ' is now available for check-in.',
                'ROOMS',
                @room_id,
                'Front Desk'
            );
        END
        
        FETCH NEXT FROM status_cursor INTO @room_id, @old_status, @new_status, @room_number;
    END
    
    CLOSE status_cursor;
    DEALLOCATE status_cursor;
END;
GO

-- =============================================
-- TRIGGER 2: trg_high_priority_maintenance
-- Sends urgent alert when high-priority or
-- critical maintenance request is created
-- =============================================
CREATE OR ALTER TRIGGER trg_high_priority_maintenance
ON MAINTENANCE_REQUESTS
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @request_id INT;
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @priority NVARCHAR(20);
    DECLARE @title NVARCHAR(200);
    DECLARE @assigned_to INT;
    DECLARE @assigned_name NVARCHAR(100);
    DECLARE @has_booking BIT = 0;
    DECLARE @booking_info NVARCHAR(200);
    
    -- Process high/critical priority requests
    DECLARE priority_cursor CURSOR FOR
        SELECT 
            i.request_id,
            i.room_id,
            i.priority,
            i.title,
            i.assigned_to
        FROM inserted i
        WHERE i.priority IN ('High', 'Critical');
    
    OPEN priority_cursor;
    FETCH NEXT FROM priority_cursor INTO @request_id, @room_id, @priority, @title, @assigned_to;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Get room number
        SELECT @room_number = room_number FROM ROOMS WHERE room_id = @room_id;
        
        -- Get assigned employee name
        IF @assigned_to IS NOT NULL
            SELECT @assigned_name = first_name + ' ' + last_name 
            FROM EMPLOYEES WHERE employee_id = @assigned_to;
        ELSE
            SET @assigned_name = 'UNASSIGNED';
        
        -- Check for upcoming or active bookings
        SELECT TOP 1 @booking_info = 
            'Booking #' + CAST(reservation_id AS NVARCHAR) + 
            ' - Check-in: ' + FORMAT(check_in_date, 'MMM dd'),
            @has_booking = 1
        FROM RESERVATIONS
        WHERE room_id = @room_id
        AND status IN ('Confirmed', 'CheckedIn')
        AND check_in_date <= DATEADD(DAY, 2, GETDATE())
        ORDER BY check_in_date;
        
        -- Create urgent notification for maintenance manager
        INSERT INTO NOTIFICATIONS (
            notification_type, title, message,
            related_table, related_id, recipient_type
        )
        VALUES (
            'UrgentMaintenance',
            '⚠️ URGENT: ' + @priority + ' Priority Maintenance',
            'Room ' + @room_number + ': ' + @title + '. ' +
            'Assigned to: ' + @assigned_name + '. ' +
            CASE WHEN @has_booking = 1 
                THEN 'ALERT: ' + @booking_info 
                ELSE 'No immediate bookings affected.'
            END,
            'MAINTENANCE_REQUESTS',
            @request_id,
            'Maintenance'
        );
        
        -- For Critical priority, also notify management
        IF @priority = 'Critical'
        BEGIN
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type
            )
            VALUES (
                'CriticalAlert',
                '🚨 CRITICAL Maintenance Alert',
                'CRITICAL maintenance needed for Room ' + @room_number + ': ' + @title + '. ' +
                'Immediate attention required. ' +
                CASE WHEN @has_booking = 1 
                    THEN 'WARNING: Affects ' + @booking_info 
                    ELSE ''
                END,
                'MAINTENANCE_REQUESTS',
                @request_id,
                'Management'
            );
            
            -- Also notify front desk for guest impact management
            IF @has_booking = 1
            BEGIN
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type
                )
                VALUES (
                    'GuestImpact',
                    'Guest Impact Alert',
                    'Room ' + @room_number + ' has a CRITICAL maintenance issue. ' +
                    @booking_info + '. May need to arrange alternative accommodation.',
                    'MAINTENANCE_REQUESTS',
                    @request_id,
                    'Front Desk'
                );
            END
        END
        
        FETCH NEXT FROM priority_cursor INTO @request_id, @room_id, @priority, @title, @assigned_to;
    END
    
    CLOSE priority_cursor;
    DEALLOCATE priority_cursor;
END;
GO

PRINT 'Tung Triggers created successfully.';
GO
