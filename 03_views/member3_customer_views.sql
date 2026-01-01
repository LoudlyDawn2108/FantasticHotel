-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- VIEWS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_customer_history
-- Complete customer history: reservations,
-- spending, loyalty status
-- =============================================
CREATE OR ALTER VIEW vw_customer_history
AS
SELECT 
    c.customer_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.email,
    c.phone,
    c.nationality,
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
    
    CASE c.membership_tier
        WHEN 'Bronze' THEN 'Silver'
        WHEN 'Silver' THEN 'Gold'
        WHEN 'Gold' THEN 'Platinum'
        ELSE 'Maximum'
    END AS next_tier,
    
    -- Reservation statistics
    (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id) AS total_reservations,
    
    (SELECT COUNT(*) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS completed_stays,
    
    (SELECT COUNT(*) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status = 'Cancelled') AS cancelled_reservations,
    
    (SELECT COUNT(*) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status IN ('Pending', 'Confirmed')) AS upcoming_reservations,
    
    -- Spending statistics
    (SELECT ISNULL(SUM(total_amount), 0) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS total_reservation_value,
    
    (SELECT ISNULL(AVG(total_amount), 0) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS average_stay_value,
    
    -- Last activity
    (SELECT MAX(check_out_date) FROM RESERVATIONS r 
     WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS last_stay_date,
    
    (SELECT TOP 1 rm.room_number FROM RESERVATIONS r 
     INNER JOIN ROOMS rm ON r.room_id = rm.room_id
     WHERE r.customer_id = c.customer_id 
     ORDER BY r.created_at DESC) AS last_room,
    
    -- Review statistics
    (SELECT COUNT(*) FROM REVIEWS rv WHERE rv.customer_id = c.customer_id) AS reviews_given,
    
    (SELECT ISNULL(AVG(CAST(rating AS DECIMAL(3,2))), 0) FROM REVIEWS rv 
     WHERE rv.customer_id = c.customer_id) AS average_rating_given,
    
    -- Customer status
    CASE 
        WHEN DATEDIFF(DAY, 
            (SELECT MAX(check_out_date) FROM RESERVATIONS r 
             WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut'), 
            GETDATE()) <= 90 THEN 'Active'
        WHEN DATEDIFF(DAY, 
            (SELECT MAX(check_out_date) FROM RESERVATIONS r 
             WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut'), 
            GETDATE()) <= 365 THEN 'Regular'
        WHEN (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id) = 0 THEN 'New'
        ELSE 'Inactive'
    END AS customer_status

FROM CUSTOMERS c
WHERE c.is_active = 1;
GO

-- =============================================
-- VIEW 2: vw_popular_services
-- Service usage statistics, revenue by category,
-- trending services
-- =============================================
CREATE OR ALTER VIEW vw_popular_services
AS
SELECT 
    s.service_id,
    s.service_name,
    sc.category_name,
    s.price AS current_price,
    s.description,
    s.is_active,
    
    -- Usage statistics (all time)
    ISNULL(
        (SELECT SUM(su.quantity) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id AND su.status = 'Completed'),
        0
    ) AS total_times_used,
    
    ISNULL(
        (SELECT COUNT(DISTINCT su.reservation_id) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id AND su.status = 'Completed'),
        0
    ) AS unique_reservations,
    
    -- Revenue statistics
    ISNULL(
        (SELECT SUM(su.total_price) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id AND su.status = 'Completed'),
        0
    ) AS total_revenue,
    
    ISNULL(
        (SELECT AVG(su.total_price) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id AND su.status = 'Completed'),
        0
    ) AS average_transaction_value,
    
    -- Last 30 days statistics
    ISNULL(
        (SELECT SUM(su.quantity) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id 
         AND su.status = 'Completed'
         AND su.used_date >= DATEADD(DAY, -30, GETDATE())),
        0
    ) AS uses_last_30_days,
    
    ISNULL(
        (SELECT SUM(su.total_price) FROM SERVICES_USED su 
         WHERE su.service_id = s.service_id 
         AND su.status = 'Completed'
         AND su.used_date >= DATEADD(DAY, -30, GETDATE())),
        0
    ) AS revenue_last_30_days,
    
    -- Trend indicator (compare last 30 days vs previous 30 days)
    CASE 
        WHEN ISNULL(
            (SELECT SUM(su.quantity) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id 
             AND su.status = 'Completed'
             AND su.used_date >= DATEADD(DAY, -30, GETDATE())),
            0
        ) > ISNULL(
            (SELECT SUM(su.quantity) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id 
             AND su.status = 'Completed'
             AND su.used_date BETWEEN DATEADD(DAY, -60, GETDATE()) AND DATEADD(DAY, -30, GETDATE())),
            0
        ) THEN 'Trending Up'
        WHEN ISNULL(
            (SELECT SUM(su.quantity) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id 
             AND su.status = 'Completed'
             AND su.used_date >= DATEADD(DAY, -30, GETDATE())),
            0
        ) < ISNULL(
            (SELECT SUM(su.quantity) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id 
             AND su.status = 'Completed'
             AND su.used_date BETWEEN DATEADD(DAY, -60, GETDATE()) AND DATEADD(DAY, -30, GETDATE())),
            0
        ) THEN 'Trending Down'
        ELSE 'Stable'
    END AS trend_indicator,
    
    -- Category ranking
    RANK() OVER (
        PARTITION BY s.category_id 
        ORDER BY ISNULL(
            (SELECT SUM(su.total_price) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id AND su.status = 'Completed'),
            0
        ) DESC
    ) AS category_rank,
    
    -- Overall ranking
    RANK() OVER (
        ORDER BY ISNULL(
            (SELECT SUM(su.total_price) FROM SERVICES_USED su 
             WHERE su.service_id = s.service_id AND su.status = 'Completed'),
            0
        ) DESC
    ) AS overall_rank,
    
    -- Last used
    (SELECT MAX(su.used_date) FROM SERVICES_USED su 
     WHERE su.service_id = s.service_id AND su.status = 'Completed') AS last_used

FROM SERVICES s
INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id;
GO

PRINT 'Ninh Views created successfully.';
GO
