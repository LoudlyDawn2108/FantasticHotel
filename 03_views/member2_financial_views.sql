-- Khanh: VIEWS (Simplified)
USE HotelManagement;
GO

-- vw_daily_revenue_report: Daily revenue summary
CREATE OR ALTER VIEW vw_daily_revenue_report AS
SELECT CAST(payment_date AS DATE) AS report_date,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total_payments,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) AS refunds,
    SUM(CASE WHEN payment_method = 'Cash' THEN amount ELSE 0 END) AS cash,
    SUM(CASE WHEN payment_method = 'Credit Card' THEN amount ELSE 0 END) AS credit_card,
    COUNT(*) AS transactions
FROM PAYMENTS WHERE status = 'Completed'
GROUP BY CAST(payment_date AS DATE);
GO

-- vw_outstanding_payments: Unpaid balances
CREATE OR ALTER VIEW vw_outstanding_payments AS
SELECT r.reservation_id, c.first_name + ' ' + c.last_name AS customer, c.email, rm.room_number,
    r.total_amount, r.paid_amount, (r.total_amount - r.paid_amount) AS balance,
    DATEDIFF(DAY, r.check_out_date, GETDATE()) AS days_overdue,
    CASE WHEN (r.total_amount - r.paid_amount) >= 1000 THEN 'High' 
         WHEN (r.total_amount - r.paid_amount) >= 500 THEN 'Medium' ELSE 'Low' END AS priority
FROM RESERVATIONS r
JOIN CUSTOMERS c ON r.customer_id = c.customer_id
JOIN ROOMS rm ON r.room_id = rm.room_id
WHERE r.total_amount > r.paid_amount AND r.status NOT IN ('Cancelled','NoShow');
GO
