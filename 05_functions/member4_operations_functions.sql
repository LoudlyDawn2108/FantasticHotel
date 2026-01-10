-- =============================================
-- TUNG (Member 4): HÀM - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- HÀM 1: fn_calculate_sla_status
-- Mục đích: Tính trạng thái SLA dựa trên độ ưu tiên và thời gian
-- Được sử dụng trong: vw_maintenance_dashboard (VIEW)
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_sla_status(
    @priority NVARCHAR(20),     -- Độ ưu tiên: Critical, High, Medium, Low
    @status NVARCHAR(20),       -- Trạng thái hiện tại
    @created DATETIME           -- Thời điểm tạo yêu cầu
)
RETURNS NVARCHAR(20) AS
BEGIN
    -- Nếu đã hoàn thành thì trả về Completed
    IF @status = 'Completed' RETURN 'Completed';
    
    -- Tính số giờ đã trôi qua
    DECLARE @hours INT = DATEDIFF(HOUR, @created, GETDATE());
    
    -- Trả về trạng thái SLA dựa trên độ ưu tiên và thời gian
    RETURN CASE 
        -- SLA Breached: Đã vượt quá thời gian cho phép
        WHEN @priority = 'Critical' AND @hours > 4 THEN 'SLA Breached'
        WHEN @priority = 'High' AND @hours > 12 THEN 'SLA Breached'
        WHEN @priority = 'Medium' AND @hours > 24 THEN 'SLA Breached'
        WHEN @priority = 'Low' AND @hours > 48 THEN 'SLA Breached'
        -- At Risk: Gần vượt thời gian cho phép
        WHEN @priority = 'Critical' AND @hours > 2 THEN 'At Risk'
        WHEN @priority = 'High' AND @hours > 8 THEN 'At Risk'
        -- On Track: Vẫn trong thời gian cho phép
        ELSE 'On Track' 
    END;
END;
GO

-- =============================================
-- HÀM 2: fn_calculate_maintenance_cost
-- Mục đích: Tính tổng chi phí bảo trì trong khoảng thời gian
-- Được sử dụng trong: vw_maintenance_cost_statistics (VIEW)
-- Đây là hàm tính tổng tiền theo yêu cầu giảng viên
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_maintenance_cost(
    @from_date DATE,    -- Ngày bắt đầu
    @to_date DATE       -- Ngày kết thúc
)
RETURNS DECIMAL(15,2) AS
BEGIN
    DECLARE @total DECIMAL(15,2);
    
    -- Tính tổng chi phí thực tế của các yêu cầu đã hoàn thành
    SELECT @total = ISNULL(SUM(actual_cost), 0)
    FROM MAINTENANCE_REQUESTS
    WHERE status = 'Completed'
    AND completed_at >= @from_date 
    AND completed_at < DATEADD(DAY, 1, @to_date);
    
    RETURN @total;
END;
GO

PRINT 'Tung: Đã tạo 2 hàm thành công!';
GO
