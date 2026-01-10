-- =============================================
-- TUNG (Member 4): VIEW - QUẢN LÝ VẬN HÀNH & NHÂN SỰ
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_maintenance_dashboard
-- Mục đích: Hiển thị tổng quan các yêu cầu bảo trì
-- Liên kết: GỌI HÀM fn_calculate_sla_status để tính trạng thái SLA
-- =============================================
CREATE OR ALTER VIEW vw_maintenance_dashboard AS
SELECT 
    mr.request_id,                                      -- Mã yêu cầu
    rm.room_number,                                     -- Số phòng
    mr.title,                                           -- Tiêu đề yêu cầu
    mr.priority,                                        -- Độ ưu tiên
    mr.status,                                          -- Trạng thái
    e.first_name + ' ' + e.last_name AS assigned_to,    -- Nhân viên được giao
    mr.created_at,                                      -- Thời điểm tạo
    DATEDIFF(HOUR, mr.created_at, ISNULL(mr.completed_at, GETDATE())) AS hours_elapsed,  -- Số giờ đã qua
    dbo.fn_calculate_sla_status(mr.priority, mr.status, mr.created_at) AS sla_status     -- GỌI HÀM: Trạng thái SLA
FROM MAINTENANCE_REQUESTS mr
JOIN ROOMS rm ON mr.room_id = rm.room_id
LEFT JOIN EMPLOYEES e ON mr.assigned_to = e.employee_id;
GO

-- =============================================
-- VIEW 2: vw_employee_performance
-- Mục đích: Thống kê hiệu suất làm việc của nhân viên
-- =============================================
CREATE OR ALTER VIEW vw_employee_performance AS
SELECT 
    e.employee_id,                                      -- Mã nhân viên
    e.first_name + ' ' + e.last_name AS name,           -- Họ tên
    d.department_name,                                  -- Phòng ban
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS WHERE employee_id = e.employee_id) AS total_shifts,           -- Tổng ca
    (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS WHERE employee_id = e.employee_id AND status = 'Completed') AS completed,  -- Ca hoàn thành
    (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS WHERE assigned_to = e.employee_id AND status = 'Completed') AS tasks_done  -- Task hoàn thành
FROM EMPLOYEES e 
JOIN DEPARTMENTS d ON e.department_id = d.department_id 
WHERE e.is_active = 1;
GO

-- =============================================
-- VIEW 3: vw_maintenance_cost_statistics
-- Mục đích: Thống kê chi phí bảo trì theo ngày/tuần/tháng/quý/năm
-- Liên kết: GỌI HÀM fn_calculate_maintenance_cost để tính tổng tiền
-- Đây là view thống kê gọi hàm tính tiền theo yêu cầu giảng viên
-- =============================================
CREATE OR ALTER VIEW vw_maintenance_cost_statistics AS
SELECT 
    -- Chi phí hôm nay
    dbo.fn_calculate_maintenance_cost(
        CAST(GETDATE() AS DATE), 
        CAST(GETDATE() AS DATE)
    ) AS today_cost,
    
    -- Chi phí tuần này (7 ngày gần nhất)
    dbo.fn_calculate_maintenance_cost(
        DATEADD(DAY, -7, CAST(GETDATE() AS DATE)), 
        CAST(GETDATE() AS DATE)
    ) AS week_cost,
    
    -- Chi phí tháng này
    dbo.fn_calculate_maintenance_cost(
        DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1), 
        CAST(GETDATE() AS DATE)
    ) AS month_cost,
    
    -- Chi phí quý này
    dbo.fn_calculate_maintenance_cost(
        DATEFROMPARTS(YEAR(GETDATE()), ((DATEPART(QUARTER, GETDATE()) - 1) * 3) + 1, 1), 
        CAST(GETDATE() AS DATE)
    ) AS quarter_cost,
    
    -- Chi phí năm này
    dbo.fn_calculate_maintenance_cost(
        DATEFROMPARTS(YEAR(GETDATE()), 1, 1), 
        CAST(GETDATE() AS DATE)
    ) AS year_cost,
    
    -- Thông tin bổ sung
    CAST(GETDATE() AS DATE) AS report_date,             -- Ngày báo cáo
    MONTH(GETDATE()) AS current_month,                  -- Tháng hiện tại
    DATEPART(QUARTER, GETDATE()) AS current_quarter,    -- Quý hiện tại
    YEAR(GETDATE()) AS current_year;                    -- Năm hiện tại
GO

PRINT 'Tung: Đã tạo 3 view thành công!';
GO
