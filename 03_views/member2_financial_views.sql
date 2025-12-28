-- =============================================
-- MEMBER 2: PAYMENT & FINANCIAL MANAGEMENT
-- VIEWS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_daily_revenue_report
-- Daily revenue breakdown by room type, services,
-- and payment method
-- =============================================
CREATE OR ALTER VIEW vw_daily_revenue_report
AS
WITH DailyPayments AS (
    SELECT 
        CAST(payment_date AS DATE) AS payment_date,
        SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_payments,
        SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS total_refunds,
        SUM(CASE WHEN payment_method = 'Cash' AND amount > 0 THEN amount ELSE 0 END) AS cash_payments,
        SUM(CASE WHEN payment_method = 'Credit Card' AND amount > 0 THEN amount ELSE 0 END) AS credit_card_payments,
        SUM(CASE WHEN payment_method = 'Debit Card' AND amount > 0 THEN amount ELSE 0 END) AS debit_card_payments,
        SUM(CASE WHEN payment_method = 'Bank Transfer' AND amount > 0 THEN amount ELSE 0 END) AS bank_transfer_payments,
        SUM(CASE WHEN payment_method = 'Mobile Payment' AND amount > 0 THEN amount ELSE 0 END) AS mobile_payments,
        COUNT(CASE WHEN amount > 0 THEN 1 END) AS transaction_count
    FROM PAYMENTS
    WHERE status = 'Completed'
    GROUP BY CAST(payment_date AS DATE)
),
DailyRoomRevenue AS (
    SELECT 
        CAST(p.payment_date AS DATE) AS payment_date,
        rt.type_name AS room_type,
        SUM(CASE WHEN p.amount > 0 THEN 
            (r.room_charge / NULLIF(r.total_amount, 0)) * p.amount 
            ELSE 0 END) AS room_revenue
    FROM PAYMENTS p
    INNER JOIN RESERVATIONS r ON p.reservation_id = r.reservation_id
    INNER JOIN ROOMS rm ON r.room_id = rm.room_id
    INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
    WHERE p.status = 'Completed' AND p.amount > 0
    GROUP BY CAST(p.payment_date AS DATE), rt.type_name
),
DailyServiceRevenue AS (
    SELECT 
        CAST(su.used_date AS DATE) AS service_date,
        sc.category_name,
        SUM(su.total_price) AS service_revenue
    FROM SERVICES_USED su
    INNER JOIN SERVICES s ON su.service_id = s.service_id
    INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
    WHERE su.status = 'Completed'
    GROUP BY CAST(su.used_date AS DATE), sc.category_name
)
SELECT 
    dp.payment_date AS report_date,
    DATENAME(WEEKDAY, dp.payment_date) AS day_of_week,
    dp.total_payments,
    dp.total_refunds,
    (dp.total_payments - dp.total_refunds) AS net_revenue,
    dp.transaction_count,
    
    -- Payment method breakdown
    dp.cash_payments,
    dp.credit_card_payments,
    dp.debit_card_payments,
    dp.bank_transfer_payments,
    dp.mobile_payments,
    
    -- Room revenue by type (pivoted)
    ISNULL((SELECT SUM(room_revenue) FROM DailyRoomRevenue drr WHERE drr.payment_date = dp.payment_date AND drr.room_type = 'Standard'), 0) AS standard_room_revenue,
    ISNULL((SELECT SUM(room_revenue) FROM DailyRoomRevenue drr WHERE drr.payment_date = dp.payment_date AND drr.room_type = 'Superior'), 0) AS superior_room_revenue,
    ISNULL((SELECT SUM(room_revenue) FROM DailyRoomRevenue drr WHERE drr.payment_date = dp.payment_date AND drr.room_type = 'Deluxe'), 0) AS deluxe_room_revenue,
    ISNULL((SELECT SUM(room_revenue) FROM DailyRoomRevenue drr WHERE drr.payment_date = dp.payment_date AND drr.room_type = 'Suite'), 0) AS suite_revenue,
    ISNULL((SELECT SUM(room_revenue) FROM DailyRoomRevenue drr WHERE drr.payment_date = dp.payment_date AND drr.room_type = 'Presidential Suite'), 0) AS presidential_revenue,
    
    -- Service revenue by category
    ISNULL((SELECT SUM(service_revenue) FROM DailyServiceRevenue dsr WHERE dsr.service_date = dp.payment_date AND dsr.category_name = 'Room Service'), 0) AS room_service_revenue,
    ISNULL((SELECT SUM(service_revenue) FROM DailyServiceRevenue dsr WHERE dsr.service_date = dp.payment_date AND dsr.category_name = 'Spa & Wellness'), 0) AS spa_revenue,
    ISNULL((SELECT SUM(service_revenue) FROM DailyServiceRevenue dsr WHERE dsr.service_date = dp.payment_date), 0) AS total_service_revenue

FROM DailyPayments dp;
GO

-- =============================================
-- VIEW 2: vw_outstanding_payments
-- Unpaid/partial payments with customer details
-- and aging analysis
-- =============================================
CREATE OR ALTER VIEW vw_outstanding_payments
AS
SELECT 
    r.reservation_id,
    r.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email AS customer_email,
    c.phone AS customer_phone,
    c.membership_tier,
    
    -- Room details
    rm.room_number,
    rt.type_name AS room_type,
    
    -- Reservation dates
    r.check_in_date,
    r.check_out_date,
    r.status AS reservation_status,
    
    -- Financial details
    r.total_amount,
    r.paid_amount,
    (r.total_amount - r.paid_amount) AS outstanding_balance,
    
    -- Payment percentage
    CASE 
        WHEN r.total_amount > 0 
        THEN CAST(ROUND((r.paid_amount / r.total_amount) * 100, 2) AS DECIMAL(5,2))
        ELSE 0 
    END AS payment_percentage,
    
    -- Aging analysis
    DATEDIFF(DAY, r.check_out_date, GETDATE()) AS days_since_checkout,
    
    CASE 
        WHEN r.status = 'CheckedIn' THEN 'Current Stay'
        WHEN r.status IN ('Pending', 'Confirmed') THEN 'Upcoming'
        WHEN DATEDIFF(DAY, r.check_out_date, GETDATE()) <= 0 THEN 'Current'
        WHEN DATEDIFF(DAY, r.check_out_date, GETDATE()) BETWEEN 1 AND 7 THEN '1-7 Days'
        WHEN DATEDIFF(DAY, r.check_out_date, GETDATE()) BETWEEN 8 AND 30 THEN '8-30 Days'
        WHEN DATEDIFF(DAY, r.check_out_date, GETDATE()) BETWEEN 31 AND 60 THEN '31-60 Days'
        ELSE 'Over 60 Days'
    END AS aging_category,
    
    -- Last payment info
    (SELECT TOP 1 payment_date FROM PAYMENTS p 
     WHERE p.reservation_id = r.reservation_id AND p.status = 'Completed' AND p.amount > 0
     ORDER BY payment_date DESC) AS last_payment_date,
    
    (SELECT TOP 1 amount FROM PAYMENTS p 
     WHERE p.reservation_id = r.reservation_id AND p.status = 'Completed' AND p.amount > 0
     ORDER BY payment_date DESC) AS last_payment_amount,
    
    -- Payment count
    (SELECT COUNT(*) FROM PAYMENTS p 
     WHERE p.reservation_id = r.reservation_id AND p.status = 'Completed' AND p.amount > 0) AS payment_count,
    
    -- Priority indicator
    CASE 
        WHEN (r.total_amount - r.paid_amount) >= 1000 THEN 'High'
        WHEN (r.total_amount - r.paid_amount) >= 500 THEN 'Medium'
        ELSE 'Low'
    END AS collection_priority,
    
    r.created_at AS reservation_created

FROM RESERVATIONS r
INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
INNER JOIN ROOMS rm ON r.room_id = rm.room_id
INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
WHERE r.total_amount > r.paid_amount  -- Has outstanding balance
AND r.status NOT IN ('Cancelled', 'NoShow')  -- Exclude cancelled
ORDER BY (r.total_amount - r.paid_amount) DESC;
GO

PRINT 'Member 2 Views created successfully.';
GO
