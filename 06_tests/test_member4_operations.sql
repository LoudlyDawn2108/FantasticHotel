-- =============================================
-- MEMBER 4: TUNG - OPERATIONS & HR MANAGEMENT
-- Test Script
-- =============================================

USE HotelManagement;
GO

PRINT '========================================';
PRINT 'TESTING TUNG - OPERATIONS MODULE';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST FUNCTIONS
-- =============================================R
PRINT '--- Testing Functions ---';

PRINT 'Testing fn_get_available_staff:';
SELECT dbo.fn_get_available_staff(4, CAST(GETDATE() AS DATE)) AS fn_get_available_staff_result;
GO

PRINT 'Testing fn_calculate_sla_status:';
SELECT dbo.fn_calculate_sla_status('High', 'Open', DATEADD(HOUR, -10, GETDATE()), NULL) AS fn_calculate_sla_status_result;
GO

-- =============================================
-- TEST VIEWS
-- =============================================
PRINT '';
PRINT '--- Testing Views ---';

PRINT 'Testing vw_maintenance_dashboard:';
SELECT TOP 5 * FROM vw_maintenance_dashboard ORDER BY request_id DESC;
GO

PRINT 'Testing vw_employee_performance:';
SELECT TOP 5 * FROM vw_employee_performance ORDER BY employee_id;
GO

-- =============================================
-- TEST PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Procedures ---';

PRINT 'Testing sp_create_maintenance_request:';
DECLARE @new_request_id INT;
DECLARE @assigned_emp NVARCHAR(100);
DECLARE @maint_message NVARCHAR(500);
EXEC sp_create_maintenance_request
    @user_id = 1,
    @room_id = 1,
    @title = 'Test Maintenance Request',
    @description = 'This is a test maintenance request',
    @priority = 'Medium',
    @request_id = @new_request_id OUTPUT,
    @assigned_employee = @assigned_emp OUTPUT,
    @message = @maint_message OUTPUT;
PRINT 'Result: ' + @maint_message;
PRINT 'Request ID: ' + ISNULL(CAST(@new_request_id AS NVARCHAR), 'NULL');
GO

PRINT '';
PRINT 'Testing sp_complete_maintenance:';
DECLARE @response_hours DECIMAL(10,2);
DECLARE @complete_message NVARCHAR(500);
-- Use a valid request_id from test data
EXEC sp_complete_maintenance
    @user_id = 1,
    @request_id = 1,
    @actual_cost = 150.00,
    @completion_notes = 'Test completion',
    @response_time_hours = @response_hours OUTPUT,
    @message = @complete_message OUTPUT;
PRINT 'Result: ' + @complete_message;
GO

-- =============================================
-- TEST STANDALONE CURSORS (07_cursors)
-- =============================================
PRINT '';
PRINT '--- Testing Standalone Cursors ---';
PRINT 'Note: Standalone cursors in 07_cursors/ should be run separately';
PRINT 'Files: member4_operations_cursor.sql';
GO

-- =============================================
-- TEST TRIGGERS (check notifications)
-- =============================================
PRINT '';
PRINT '--- Testing Triggers (via notifications) ---';

PRINT 'Recent Notifications from Triggers:';
SELECT TOP 10
    notification_id,
    notification_type,
    title,
    LEFT(message, 60) AS message_preview,
    recipient_type,
    created_at
FROM NOTIFICATIONS 
WHERE notification_type IN ('UrgentMaintenance', 'CriticalAlert', 'TaskAssignment', 'RoomCleaning', 'RoomAvailable', 'MaintenanceComplete')
ORDER BY created_at DESC;
GO

PRINT 'Room Status History:';
SELECT TOP 10 * FROM ROOM_STATUS_HISTORY ORDER BY changed_at DESC;
GO

PRINT '';
PRINT '========================================';
PRINT 'TUNG TESTS COMPLETED';
PRINT '========================================';
GO
