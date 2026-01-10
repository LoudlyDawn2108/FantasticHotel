-- =============================================
-- MEMBER 2: KHANH - PAYMENT & FINANCIAL MANAGEMENT
-- Test Script
-- =============================================

USE HotelManagement;
GO

PRINT '========================================';
PRINT 'TESTING KHANH - PAYMENT MODULE';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST FUNCTIONS
-- =============================================
PRINT '--- Testing Functions ---';

PRINT 'Testing fn_calculate_loyalty_points:';
SELECT dbo.fn_calculate_loyalty_points(500.00, 'Gold') AS fn_calculate_loyalty_points_result;
GO

PRINT 'Testing fn_get_customer_tier:';
SELECT dbo.fn_get_customer_tier(25000.00) AS fn_get_customer_tier_result;
GO

PRINT 'Testing fn_calculate_total_bill (table function):';
SELECT * FROM dbo.fn_calculate_total_bill(1);
GO

-- =============================================
-- TEST VIEWS
-- =============================================
PRINT '';
PRINT '--- Testing Views ---';

PRINT 'Testing vw_daily_revenue_report:';
SELECT TOP 5 * FROM vw_daily_revenue_report ORDER BY report_date DESC;
GO

PRINT 'Testing vw_outstanding_payments:';
SELECT TOP 5 * FROM vw_outstanding_payments;
GO

-- =============================================
-- TEST PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Procedures ---';

PRINT 'Testing sp_process_payment:';
DECLARE @payment_id INT;
DECLARE @payment_message NVARCHAR(500);
EXEC sp_process_payment
    @user_id = 1,
    @reservation_id = 1,
    @amount = 100.00,
    @payment_method = 'Credit Card',
    @payment_id = @payment_id OUTPUT,
    @message = @payment_message OUTPUT;
PRINT 'Result: ' + @payment_message;
GO

PRINT 'Testing sp_generate_invoice:';
DECLARE @invoice_output NVARCHAR(MAX);
DECLARE @invoice_message NVARCHAR(500);
EXEC sp_generate_invoice
    @user_id = 1,
    @reservation_id = 1,
    @invoice_output = @invoice_output OUTPUT,
    @message = @invoice_message OUTPUT;
PRINT 'Result: ' + @invoice_message;
GO

-- =============================================
-- TEST CURSOR PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Cursor Procedures ---';

PRINT 'Testing sp_send_payment_reminders:';
DECLARE @reminder_count INT;
DECLARE @outstanding_total DECIMAL(12,2);
DECLARE @reminder_message NVARCHAR(1000);
EXEC sp_send_payment_reminders
    @user_id = 1,
    @days_overdue = 0,
    @reminder_count = @reminder_count OUTPUT,
    @total_outstanding = @outstanding_total OUTPUT,
    @message = @reminder_message OUTPUT;
PRINT 'Result: ' + @reminder_message;
GO

PRINT 'Testing sp_generate_monthly_revenue_summary:';
DECLARE @revenue_output NVARCHAR(MAX);
DECLARE @revenue_message NVARCHAR(500);
EXEC sp_generate_monthly_revenue_summary
    @user_id = 1,
    @year = 2024,
    @month = 12,
    @summary_output = @revenue_output OUTPUT,
    @message = @revenue_message OUTPUT;
PRINT 'Result: ' + @revenue_message;
PRINT @revenue_output;
GO

PRINT '';
PRINT '========================================';
PRINT 'KHANH TESTS COMPLETED';
PRINT '========================================';
GO
