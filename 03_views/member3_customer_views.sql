-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- VIEWS (SIMPLIFIED)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_customer_history
-- Customer overview with key statistics
-- =============================================
CREATE OR ALTER VIEW vw_customer_history
AS
WITH CustomerStats AS (
    SELECT 
        customer_id,
        COUNT(*) AS total_reservations,
        SUM(CASE WHEN status = 'CheckedOut' THEN 1 ELSE 0 END) AS completed_stays,
        SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_reservations,
        SUM(CASE WHEN status IN ('Pending', 'Confirmed') THEN 1 ELSE 0 END) AS upcoming_reservations,
        SUM(CASE WHEN status = 'CheckedOut' THEN total_amount ELSE 0 END) AS total_reservation_value,
        MAX(CASE WHEN status = 'CheckedOut' THEN check_out_date END) AS last_stay_date
    FROM RESERVATIONS
    GROUP BY customer_id
)
SELECT 
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    c.phone,
    c.membership_tier,
    c.loyalty_points,
    c.total_spending,
    c.created_at AS member_since,
    
    -- Tier progress
    CASE c.membership_tier
        WHEN 'Bronze' THEN 5000 - c.total_spending
        WHEN 'Silver' THEN 20000 - c.total_spending
        WHEN 'Gold' THEN 50000 - c.total_spending
        ELSE 0
    END AS spending_to_next_tier,
    
    -- Reservation statistics
    ISNULL(cs.total_reservations, 0) AS total_reservations,
    ISNULL(cs.completed_stays, 0) AS completed_stays,
    ISNULL(cs.cancelled_reservations, 0) AS cancelled_reservations,
    ISNULL(cs.upcoming_reservations, 0) AS upcoming_reservations,
    ISNULL(cs.total_reservation_value, 0) AS total_reservation_value,
    cs.last_stay_date,
    
    -- Customer status
    CASE 
        WHEN DATEDIFF(DAY, cs.last_stay_date, GETDATE()) <= 90 THEN 'Active'
        WHEN DATEDIFF(DAY, cs.last_stay_date, GETDATE()) <= 365 THEN 'Regular'
        WHEN cs.total_reservations = 0 THEN 'New'
        ELSE 'Inactive'
    END AS customer_status

FROM CUSTOMERS c
LEFT JOIN CustomerStats cs ON c.customer_id = cs.customer_id
WHERE c.is_active = 1;
GO

-- =============================================
-- VIEW 2: vw_popular_services
-- Service usage statistics and rankings
-- =============================================
CREATE OR ALTER VIEW vw_popular_services
AS
WITH ServiceStats AS (
    SELECT 
        service_id,
        SUM(quantity) AS total_times_used,
        COUNT(DISTINCT reservation_id) AS unique_reservations,
        SUM(total_price) AS total_revenue,
        SUM(CASE WHEN used_date >= DATEADD(DAY, -30, GETDATE()) THEN quantity ELSE 0 END) AS uses_last_30_days,
        SUM(CASE WHEN used_date >= DATEADD(DAY, -30, GETDATE()) THEN total_price ELSE 0 END) AS revenue_last_30_days,
        MAX(used_date) AS last_used
    FROM SERVICES_USED
    WHERE status = 'Completed'
    GROUP BY service_id
)
SELECT 
    s.service_id,
    s.service_name,
    sc.category_name,
    s.price AS current_price,
    s.is_active,
    
    -- Usage statistics
    ISNULL(ss.total_times_used, 0) AS total_times_used,
    ISNULL(ss.unique_reservations, 0) AS unique_reservations,
    ISNULL(ss.total_revenue, 0) AS total_revenue,
    ISNULL(ss.uses_last_30_days, 0) AS uses_last_30_days,
    ISNULL(ss.revenue_last_30_days, 0) AS revenue_last_30_days,
    ss.last_used,
    
    -- Rankings
    RANK() OVER (PARTITION BY s.category_id ORDER BY ISNULL(ss.total_revenue, 0) DESC) AS category_rank,
    RANK() OVER (ORDER BY ISNULL(ss.total_revenue, 0) DESC) AS overall_rank

FROM SERVICES s
INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
LEFT JOIN ServiceStats ss ON s.service_id = ss.service_id;
GO

PRINT 'Ninh Views created successfully.';
GO
