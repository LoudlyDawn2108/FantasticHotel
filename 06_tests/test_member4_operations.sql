-- =============================================
-- TUNG (Member 4): KIỂM THỬ - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

PRINT N'=== BẮT ĐẦU KIỂM THỬ MODULE TUNG ===';
GO

-- =============================================
-- KIỂM THỬ HÀM (FUNCTIONS)
-- =============================================
PRINT N'--- Kiểm thử Hàm ---';

-- Test hàm fn_calculate_sla_status
PRINT N'Test fn_calculate_sla_status (Tính trạng thái SLA):';
SELECT dbo.fn_calculate_sla_status('High', 'Open', DATEADD(HOUR, -10, GETDATE())) AS ket_qua_sla;
GO

-- Test hàm fn_calculate_maintenance_cost
PRINT N'Test fn_calculate_maintenance_cost (Tính tổng chi phí bảo trì năm nay):';
SELECT dbo.fn_calculate_maintenance_cost(DATEFROMPARTS(YEAR(GETDATE()), 1, 1), CAST(GETDATE() AS DATE)) AS chi_phi_nam_nay;
GO

-- =============================================
-- KIỂM THỬ VIEW
-- =============================================
PRINT N'--- Kiểm thử View ---';

-- Test vw_maintenance_dashboard (GỌI HÀM fn_calculate_sla_status)
PRINT N'Test vw_maintenance_dashboard (Dashboard bảo trì - gọi hàm SLA):';
SELECT TOP 5 * FROM vw_maintenance_dashboard ORDER BY request_id DESC;
GO

-- Test vw_employee_performance
PRINT N'Test vw_employee_performance (Hiệu suất nhân viên):';
SELECT TOP 5 * FROM vw_employee_performance ORDER BY employee_id;
GO

-- Test vw_maintenance_cost_statistics (GỌI HÀM fn_calculate_maintenance_cost)
PRINT N'Test vw_maintenance_cost_statistics (Thống kê chi phí - gọi hàm tính tiền):';
SELECT * FROM vw_maintenance_cost_statistics;
GO

-- =============================================
-- KIỂM THỬ THỦ TỤC (PROCEDURES)
-- =============================================
PRINT N'--- Kiểm thử Thủ tục ---';

-- Test sp_create_maintenance_request
PRINT N'Test sp_create_maintenance_request (Tạo yêu cầu bảo trì):';
DECLARE @req_id INT, @assigned NVARCHAR(100);
EXEC sp_create_maintenance_request 
    @room_id = 1, 
    @title = N'Test yêu cầu bảo trì', 
    @priority = 'Medium',
    @req_id = @req_id OUTPUT, 
    @assigned = @assigned OUTPUT;
PRINT N'Đã tạo Yêu cầu #' + ISNULL(CAST(@req_id AS NVARCHAR), 'NULL') + N', Phân công: ' + ISNULL(@assigned, 'NULL');
GO

-- Test sp_complete_maintenance
PRINT N'Test sp_complete_maintenance (Hoàn thành bảo trì):';
DECLARE @hours DECIMAL(10,2);
EXEC sp_complete_maintenance 
    @req_id = 1, 
    @cost = 150.00, 
    @hours = @hours OUTPUT;
PRINT N'Thời gian xử lý: ' + ISNULL(CAST(@hours AS NVARCHAR), 'NULL') + N' giờ';
GO

-- =============================================
-- KIỂM THỬ TRIGGER
-- =============================================
PRINT N'--- Kiểm thử Trigger ---';

-- Test trg_room_status_history bằng cách thay đổi trạng thái phòng
PRINT N'Test trg_room_status_history (Trigger ghi lịch sử phòng):';
UPDATE ROOMS SET status = 'Cleaning' WHERE room_id = 1;
UPDATE ROOMS SET status = 'Available' WHERE room_id = 1;
UPDATE ROOMS SET status = 'Maintenance' WHERE room_id = 2;
GO

-- Xem kết quả trigger
PRINT N'Lịch sử thay đổi trạng thái phòng:';
SELECT TOP 5 * FROM ROOM_STATUS_HISTORY ORDER BY changed_at DESC;
GO

-- =============================================
-- KẾT THÚC
-- =============================================
PRINT N'=== HOÀN THÀNH KIỂM THỬ MODULE TUNG ===';
GO
