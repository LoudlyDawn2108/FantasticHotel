-- =============================================
-- HOTEL MANAGEMENT SYSTEM - TEST SCRIPT
-- Run this script to test all SQL objects
-- =============================================

USE HotelManagement;
GO

PRINT '========================================';
PRINT 'TESTING HOTEL MANAGEMENT SYSTEM';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST FUNCTIONS
-- =============================================

PRINT '--- Testing Functions ---';
PRINT '';

-- Test fn_check_room_availability
PRINT 'Testing fn_check_room_availability:';
SELECT dbo.fn_check_room_availability(1, '2025-01-15', '2025-01-18') AS availability_room_1;
GO

-- Test fn_calculate_room_price
PRINT 'Testing fn_calculate_room_price:';
SELECT dbo.fn_calculate_room_price(1, '2025-01-15', '2025-01-18', 1) AS calculated_price;
GO

-- Test fn_calculate_loyalty_points
PRINT 'Testing fn_calculate_loyalty_points:';
SELECT dbo.fn_calculate_loyalty_points(500.00, 'Gold') AS points_earned;
GO

-- Test fn_get_customer_tier
PRINT 'Testing fn_get_customer_tier:';
SELECT dbo.fn_get_customer_tier(25000.00) AS tier_level;
GO

-- Test fn_get_available_staff
PRINT 'Testing fn_get_available_staff:';
SELECT dbo.fn_get_available_staff(4, CAST(GETDATE() AS DATE)) AS available_maintenance_staff;
GO

-- Test fn_calculate_total_bill (table function)
PRINT 'Testing fn_calculate_total_bill:';
SELECT * FROM dbo.fn_calculate_total_bill(1);
GO

-- Test fn_get_customer_statistics (table function)
PRINT 'Testing fn_get_customer_statistics:';
SELECT * FROM dbo.fn_get_customer_statistics(1);
GO

-- Test fn_calculate_sla_status
PRINT 'Testing fn_calculate_sla_status:';
SELECT dbo.fn_calculate_sla_status('High', 'Open', DATEADD(HOUR, -10, GETDATE()), NULL) AS sla_status;
GO

-- =============================================
-- TEST VIEWS
-- =============================================

PRINT '';
PRINT '--- Testing Views ---';
PRINT '';

-- Test vw_room_availability
PRINT 'Testing vw_room_availability:';
SELECT TOP 5 * FROM vw_room_availability ORDER BY room_id;
GO

-- Test vw_occupancy_statistics
PRINT 'Testing vw_occupancy_statistics:';
SELECT TOP 5 * FROM vw_occupancy_statistics ORDER BY report_date DESC;
GO

-- Test vw_daily_revenue_report
PRINT 'Testing vw_daily_revenue_report:';
SELECT TOP 5 * FROM vw_daily_revenue_report ORDER BY report_date DESC;
GO

-- Test vw_outstanding_payments
PRINT 'Testing vw_outstanding_payments:';
SELECT TOP 5 * FROM vw_outstanding_payments;
GO

-- Test vw_customer_history
PRINT 'Testing vw_customer_history:';
SELECT TOP 5 * FROM vw_customer_history ORDER BY total_spending DESC;
GO

-- Test vw_popular_services
PRINT 'Testing vw_popular_services:';
SELECT TOP 5 * FROM vw_popular_services ORDER BY overall_rank;
GO

-- Test vw_maintenance_dashboard
PRINT 'Testing vw_maintenance_dashboard:';
SELECT TOP 5 * FROM vw_maintenance_dashboard ORDER BY request_id DESC;
GO

-- Test vw_employee_performance
PRINT 'Testing vw_employee_performance:';
SELECT TOP 5 * FROM vw_employee_performance ORDER BY employee_id;
GO

-- =============================================
-- TEST BASIC PROCEDURES
-- =============================================

PRINT '';
PRINT '--- Testing Basic Procedures ---';
PRINT '';

-- Test sp_register_customer
PRINT 'Testing sp_register_customer:';
DECLARE @new_customer_id INT;
DECLARE @register_message NVARCHAR(500);
EXEC sp_register_customer 
    @first_name = 'Test',
    @last_name = 'Customer' + CAST(CAST(RAND()*1000 AS INT) AS NVARCHAR),
    @email = 'test' + CAST(CAST(RAND()*10000 AS INT) AS NVARCHAR) + '@email.com',
    @phone = '555-9999',
    @customer_id = @new_customer_id OUTPUT,
    @message = @register_message OUTPUT;
PRINT 'Result: ' + @register_message;
PRINT 'Customer ID: ' + ISNULL(CAST(@new_customer_id AS NVARCHAR), 'NULL');
GO

-- Test sp_create_reservation
PRINT '';
PRINT 'Testing sp_create_reservation:';
DECLARE @new_reservation_id INT;
DECLARE @reservation_message NVARCHAR(500);
EXEC sp_create_reservation
    @customer_id = 1,
    @room_id = 1,
    @check_in_date = '2025-02-01',
    @check_out_date = '2025-02-03',
    @num_guests = 2,
    @reservation_id = @new_reservation_id OUTPUT,
    @message = @reservation_message OUTPUT;
PRINT 'Result: ' + @reservation_message;
GO

-- Test sp_create_maintenance_request
PRINT '';
PRINT 'Testing sp_create_maintenance_request:';
DECLARE @new_request_id INT;
DECLARE @assigned_emp NVARCHAR(100);
DECLARE @maint_message NVARCHAR(500);
EXEC sp_create_maintenance_request
    @room_id = 1,
    @title = 'Test Maintenance Request',
    @description = 'This is a test maintenance request',
    @priority = 'Medium',
    @request_id = @new_request_id OUTPUT,
    @assigned_employee = @assigned_emp OUTPUT,
    @message = @maint_message OUTPUT;
PRINT 'Result: ' + @maint_message;
GO

-- =============================================
-- TEST CURSOR PROCEDURES
-- =============================================

PRINT '';
PRINT '========================================';
PRINT 'TESTING CURSOR PROCEDURES (8 CURSORS)';
PRINT '========================================';
PRINT '';

-- =============================================
-- Phuc CURSORS
-- =============================================
PRINT '--- Phuc Cursor Procedures ---';
PRINT '';

-- Test sp_process_daily_checkins
PRINT 'Testing sp_process_daily_checkins:';
DECLARE @checkin_count INT;
DECLARE @checkin_message NVARCHAR(1000);
EXEC sp_process_daily_checkins
    @processed_count = @checkin_count OUTPUT,
    @message = @checkin_message OUTPUT;
PRINT 'Result: ' + @checkin_message;
PRINT 'Processed Count: ' + CAST(@checkin_count AS NVARCHAR);
GO

-- Test sp_process_noshow_reservations
PRINT '';
PRINT 'Testing sp_process_noshow_reservations:';
DECLARE @noshow_count INT;
DECLARE @noshow_penalty DECIMAL(10,2);
DECLARE @noshow_message NVARCHAR(1000);
EXEC sp_process_noshow_reservations
    @processed_count = @noshow_count OUTPUT,
    @total_penalty = @noshow_penalty OUTPUT,
    @message = @noshow_message OUTPUT;
PRINT 'Result: ' + @noshow_message;
GO

-- =============================================
-- Khanh CURSORS
-- =============================================
PRINT '';
PRINT '--- Khanh Cursor Procedures ---';
PRINT '';

-- Test sp_send_payment_reminders
PRINT 'Testing sp_send_payment_reminders:';
DECLARE @reminder_count INT;
DECLARE @outstanding_total DECIMAL(12,2);
DECLARE @reminder_message NVARCHAR(1000);
EXEC sp_send_payment_reminders
    @days_overdue = 0,
    @reminder_count = @reminder_count OUTPUT,
    @total_outstanding = @outstanding_total OUTPUT,
    @message = @reminder_message OUTPUT;
PRINT 'Result: ' + @reminder_message;
GO

-- Test sp_generate_monthly_revenue_summary
PRINT '';
PRINT 'Testing sp_generate_monthly_revenue_summary:';
DECLARE @revenue_output NVARCHAR(MAX);
DECLARE @revenue_message NVARCHAR(500);
EXEC sp_generate_monthly_revenue_summary
    @year = 2024,
    @month = 12,
    @summary_output = @revenue_output OUTPUT,
    @message = @revenue_message OUTPUT;
PRINT 'Result: ' + @revenue_message;
PRINT @revenue_output;
GO

-- =============================================
-- Ninh CURSORS
-- =============================================
PRINT '';
PRINT '--- Ninh Cursor Procedures ---';
PRINT '';

-- Test sp_process_loyalty_tier_upgrades
PRINT 'Testing sp_process_loyalty_tier_upgrades:';
DECLARE @upgrade_count INT;
DECLARE @upgrade_message NVARCHAR(1000);
EXEC sp_process_loyalty_tier_upgrades
    @upgrade_count = @upgrade_count OUTPUT,
    @message = @upgrade_message OUTPUT;
PRINT 'Result: ' + @upgrade_message;
GO

-- Test sp_generate_service_usage_report
PRINT '';
PRINT 'Testing sp_generate_service_usage_report:';
DECLARE @service_output NVARCHAR(MAX);
DECLARE @service_message NVARCHAR(500);
EXEC sp_generate_service_usage_report
    @start_date = '2024-12-01',
    @end_date = '2024-12-31',
    @report_output = @service_output OUTPUT,
    @message = @service_message OUTPUT;
PRINT 'Result: ' + @service_message;
PRINT @service_output;
GO

-- =============================================
-- Tung CURSORS
-- =============================================
PRINT '';
PRINT '--- Tung Cursor Procedures ---';
PRINT '';

-- Test sp_auto_assign_maintenance_tasks
PRINT 'Testing sp_auto_assign_maintenance_tasks:';
DECLARE @assign_count INT;
DECLARE @assign_message NVARCHAR(1000);
EXEC sp_auto_assign_maintenance_tasks
    @assigned_count = @assign_count OUTPUT,
    @message = @assign_message OUTPUT;
PRINT 'Result: ' + @assign_message;
GO

-- Test sp_generate_employee_shift_schedule
PRINT '';
PRINT 'Testing sp_generate_employee_shift_schedule:';
DECLARE @schedule_count INT;
DECLARE @schedule_message NVARCHAR(1000);
EXEC sp_generate_employee_shift_schedule
    @week_start_date = '2025-01-06',  -- A Monday
    @schedule_count = @schedule_count OUTPUT,
    @message = @schedule_message OUTPUT;
PRINT 'Result: ' + @schedule_message;
GO

-- =============================================
-- TEST TRIGGERS (check audit logs)
-- =============================================

PRINT '';
PRINT '========================================';
PRINT 'TESTING TRIGGERS (via audit logs)';
PRINT '========================================';
PRINT '';

-- Check audit logs for recent entries
PRINT 'Recent Audit Log Entries:';
SELECT TOP 10 
    log_id, table_name, operation, record_id, 
    LEFT(old_values, 50) AS old_values_preview,
    LEFT(new_values, 50) AS new_values_preview,
    changed_at
FROM AUDIT_LOGS 
ORDER BY changed_at DESC;
GO

-- Check room status history
PRINT '';
PRINT 'Recent Room Status Changes:';
SELECT TOP 10 * 
FROM ROOM_STATUS_HISTORY 
ORDER BY changed_at DESC;
GO

-- Check employee shifts (from schedule generation)
PRINT '';
PRINT 'Generated Employee Shifts (sample):';
SELECT TOP 10
    es.shift_id,
    e.first_name + ' ' + e.last_name AS employee_name,
    d.department_name,
    es.shift_date,
    es.start_time,
    es.end_time,
    es.status
FROM EMPLOYEE_SHIFTS es
INNER JOIN EMPLOYEES e ON es.employee_id = e.employee_id
INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
WHERE es.shift_date >= CAST(GETDATE() AS DATE)
ORDER BY es.shift_date, es.start_time;
GO

PRINT '';
PRINT '========================================';
PRINT 'ALL TESTS COMPLETED';
PRINT '========================================';
PRINT '';
PRINT 'Summary of Cursor Procedures Tested:';
PRINT '  Phuc: sp_process_daily_checkins, sp_process_noshow_reservations';
PRINT '  Khanh: sp_send_payment_reminders, sp_generate_monthly_revenue_summary';
PRINT '  Ninh: sp_process_loyalty_tier_upgrades, sp_generate_service_usage_report';
PRINT '  Tung: sp_auto_assign_maintenance_tasks, sp_generate_employee_shift_schedule';
PRINT '';
PRINT 'Total: 8 Cursor Procedures (2 per member)';
GO
