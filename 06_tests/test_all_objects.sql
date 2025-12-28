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

-- Test fn_get_maintenance_statistics (table function)
PRINT 'Testing fn_get_maintenance_statistics:';
SELECT * FROM dbo.fn_get_maintenance_statistics(30);
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
-- TEST PROCEDURES
-- =============================================

PRINT '';
PRINT '--- Testing Procedures ---';
PRINT '';

-- Test sp_register_customer
PRINT 'Testing sp_register_customer:';
DECLARE @new_customer_id INT;
DECLARE @register_message NVARCHAR(500);
EXEC sp_register_customer 
    @first_name = 'Test',
    @last_name = 'Customer',
    @email = 'test.customer@email.com',
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

-- Test sp_process_payment
PRINT '';
PRINT 'Testing sp_process_payment:';
DECLARE @new_payment_id INT;
DECLARE @payment_message NVARCHAR(500);
-- Use an existing reservation with outstanding balance
DECLARE @test_reservation INT;
SELECT TOP 1 @test_reservation = reservation_id 
FROM RESERVATIONS WHERE total_amount > paid_amount AND status NOT IN ('Cancelled');

IF @test_reservation IS NOT NULL
BEGIN
    EXEC sp_process_payment
        @reservation_id = @test_reservation,
        @amount = 100.00,
        @payment_method = 'Credit Card',
        @payment_id = @new_payment_id OUTPUT,
        @message = @payment_message OUTPUT;
    PRINT 'Result: ' + @payment_message;
END
ELSE
    PRINT 'No reservation with outstanding balance found for testing.';
GO

-- Test sp_generate_invoice
PRINT '';
PRINT 'Testing sp_generate_invoice:';
DECLARE @invoice_output NVARCHAR(MAX);
DECLARE @invoice_message NVARCHAR(500);
EXEC sp_generate_invoice
    @reservation_id = 1,
    @invoice_output = @invoice_output OUTPUT,
    @message = @invoice_message OUTPUT;
PRINT 'Result: ' + @invoice_message;
PRINT @invoice_output;
GO

-- Test sp_add_service_to_reservation
PRINT '';
PRINT 'Testing sp_add_service_to_reservation:';
DECLARE @new_usage_id INT;
DECLARE @service_message NVARCHAR(500);
-- Find a checked-in reservation
DECLARE @checkedin_reservation INT;
SELECT TOP 1 @checkedin_reservation = reservation_id 
FROM RESERVATIONS WHERE status = 'CheckedIn';

IF @checkedin_reservation IS NOT NULL
BEGIN
    EXEC sp_add_service_to_reservation
        @reservation_id = @checkedin_reservation,
        @service_id = 1,
        @quantity = 1,
        @usage_id = @new_usage_id OUTPUT,
        @message = @service_message OUTPUT;
    PRINT 'Result: ' + @service_message;
END
ELSE
    PRINT 'No checked-in reservation found for testing.';
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

-- Test sp_complete_maintenance
PRINT '';
PRINT 'Testing sp_complete_maintenance:';
DECLARE @response_hours DECIMAL(10,2);
DECLARE @complete_message NVARCHAR(500);
-- Find an open maintenance request
DECLARE @open_request INT;
SELECT TOP 1 @open_request = request_id 
FROM MAINTENANCE_REQUESTS WHERE status = 'Open';

IF @open_request IS NOT NULL
BEGIN
    EXEC sp_complete_maintenance
        @request_id = @open_request,
        @actual_cost = 75.00,
        @completion_notes = 'Test completion',
        @response_time_hours = @response_hours OUTPUT,
        @message = @complete_message OUTPUT;
    PRINT 'Result: ' + @complete_message;
END
ELSE
    PRINT 'No open maintenance request found for testing.';
GO

-- Test sp_cancel_reservation
PRINT '';
PRINT 'Testing sp_cancel_reservation:';
DECLARE @refund_amt DECIMAL(10,2);
DECLARE @cancel_message NVARCHAR(500);
-- Find a confirmed reservation that can be cancelled
DECLARE @cancel_reservation INT;
SELECT TOP 1 @cancel_reservation = reservation_id 
FROM RESERVATIONS WHERE status = 'Confirmed' AND check_in_date > GETDATE();

IF @cancel_reservation IS NOT NULL
BEGIN
    EXEC sp_cancel_reservation
        @reservation_id = @cancel_reservation,
        @cancellation_reason = 'Test cancellation',
        @refund_amount = @refund_amt OUTPUT,
        @message = @cancel_message OUTPUT;
    PRINT 'Result: ' + @cancel_message;
END
ELSE
    PRINT 'No cancellable reservation found for testing.';
GO

-- =============================================
-- TEST TRIGGERS (by checking audit logs)
-- =============================================

PRINT '';
PRINT '--- Testing Triggers (check audit logs) ---';
PRINT '';

-- Check audit logs for recent entries
PRINT 'Recent Audit Log Entries:';
SELECT TOP 10 * FROM AUDIT_LOGS ORDER BY changed_at DESC;
GO

-- Check notifications generated by triggers
PRINT '';
PRINT 'Recent Notifications:';
SELECT TOP 10 * FROM NOTIFICATIONS ORDER BY created_at DESC;
GO

-- Check room status history
PRINT '';
PRINT 'Recent Room Status Changes:';
SELECT TOP 10 * FROM ROOM_STATUS_HISTORY ORDER BY changed_at DESC;
GO

PRINT '';
PRINT '========================================';
PRINT 'ALL TESTS COMPLETED';
PRINT '========================================';
GO
