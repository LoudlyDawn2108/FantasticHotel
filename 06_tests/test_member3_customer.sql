-- =============================================
-- MEMBER 3: NINH - CUSTOMER & SERVICE MANAGEMENT
-- Test Script
-- =============================================

USE HotelManagement;
GO

PRINT '========================================';
PRINT 'TESTING NINH - CUSTOMER MODULE';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST FUNCTIONS
-- =============================================
PRINT '--- Testing Functions ---';

PRINT 'Testing fn_get_customer_statistics (table function):';
SELECT * FROM dbo.fn_get_customer_statistics(1);
GO

PRINT 'Testing fn_get_customer_discount_rate:';
SELECT dbo.fn_get_customer_discount_rate(1) AS fn_get_customer_discount_rate_result;
GO

-- =============================================
-- TEST VIEWS
-- =============================================
PRINT '';
PRINT '--- Testing Views ---';

PRINT 'Testing vw_customer_history:';
SELECT TOP 5 * FROM vw_customer_history ORDER BY total_spending DESC;
GO

PRINT 'Testing vw_popular_services:';
SELECT TOP 5 * FROM vw_popular_services ORDER BY overall_rank;
GO

-- =============================================
-- TEST PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Procedures ---';

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

PRINT 'Testing sp_add_service_to_reservation:';
DECLARE @usage_id INT;
DECLARE @service_message NVARCHAR(500);
EXEC sp_add_service_to_reservation
    @reservation_id = 1,
    @service_id = 1,
    @quantity = 1,
    @usage_id = @usage_id OUTPUT,
    @message = @service_message OUTPUT;
PRINT 'Result: ' + @service_message;
GO

-- =============================================
-- TEST CURSOR PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Cursor Procedures ---';

PRINT 'Testing sp_process_loyalty_tier_upgrades:';
DECLARE @upgrade_count INT;
DECLARE @upgrade_message NVARCHAR(1000);
EXEC sp_process_loyalty_tier_upgrades
    @upgrade_count = @upgrade_count OUTPUT,
    @message = @upgrade_message OUTPUT;
PRINT 'Result: ' + @upgrade_message;
GO

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

PRINT '';
PRINT '========================================';
PRINT 'NINH TESTS COMPLETED';
PRINT '========================================';
GO
