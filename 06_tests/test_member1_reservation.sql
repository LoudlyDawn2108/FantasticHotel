-- =============================================
-- MEMBER 1: PHUC - RESERVATION & ROOM MANAGEMENT
-- Test Script
-- =============================================

USE HotelManagement;
GO

PRINT '========================================';
PRINT 'TESTING PHUC - RESERVATION MODULE';
PRINT '========================================';
PRINT '';

-- =============================================
-- TEST FUNCTIONS
-- =============================================
PRINT '--- Testing Functions ---';

PRINT 'Testing fn_check_room_availability:';
SELECT dbo.fn_check_room_availability(1, '2025-01-15', '2025-01-18') AS availability_room_1;
GO

PRINT 'Testing fn_calculate_room_price:';
SELECT dbo.fn_calculate_room_price(1, '2025-01-15', '2025-01-18', 1) AS calculated_price;
GO

PRINT 'Testing fn_calculate_discount_rate:';
SELECT dbo.fn_calculate_discount_rate('Gold', 2500) AS discount_rate;
GO

-- =============================================
-- TEST VIEWS
-- =============================================
PRINT '';
PRINT '--- Testing Views ---';

PRINT 'Testing vw_room_availability:';
SELECT TOP 5 * FROM vw_room_availability ORDER BY room_id;
GO

PRINT 'Testing vw_occupancy_statistics:';
SELECT TOP 5 * FROM vw_occupancy_statistics ORDER BY report_date DESC;
GO

-- =============================================
-- TEST PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Procedures ---';

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

PRINT 'Testing sp_cancel_reservation:';
-- Note: Use a valid reservation_id from your test data
DECLARE @cancel_message NVARCHAR(500);
EXEC sp_cancel_reservation
    @reservation_id = 1,
    @cancellation_reason = 'Test cancellation',
    @message = @cancel_message OUTPUT;
PRINT 'Result: ' + @cancel_message;
GO

-- =============================================
-- TEST CURSOR PROCEDURES
-- =============================================
PRINT '';
PRINT '--- Testing Cursor Procedures ---';

PRINT 'Testing sp_process_daily_checkins:';
DECLARE @checkin_count INT;
DECLARE @checkin_message NVARCHAR(1000);
EXEC sp_process_daily_checkins
    @processed_count = @checkin_count OUTPUT,
    @message = @checkin_message OUTPUT;
PRINT 'Result: ' + @checkin_message;
GO

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

PRINT '';
PRINT '========================================';
PRINT 'PHUC TESTS COMPLETED';
PRINT '========================================';
GO
