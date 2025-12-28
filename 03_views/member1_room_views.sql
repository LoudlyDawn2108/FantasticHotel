-- =============================================
-- MEMBER 1: RESERVATION & ROOM MANAGEMENT
-- VIEWS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- VIEW 1: vw_room_availability
-- Real-time room availability with type, price,
-- and current status information
-- =============================================
CREATE OR ALTER VIEW vw_room_availability
AS
SELECT 
    r.room_id,
    r.room_number,
    r.floor,
    rt.type_name AS room_type,
    rt.description AS room_description,
    rt.base_price,
    rt.capacity AS max_guests,
    rt.amenities,
    r.status AS current_status,
    
    -- Check if room is currently available (no overlapping reservations)
    CASE 
        WHEN r.status IN ('Maintenance', 'Cleaning') THEN 'Not Available'
        WHEN EXISTS (
            SELECT 1 FROM RESERVATIONS res 
            WHERE res.room_id = r.room_id 
            AND res.status IN ('Confirmed', 'CheckedIn')
            AND CAST(GETDATE() AS DATE) BETWEEN res.check_in_date AND DATEADD(DAY, -1, res.check_out_date)
        ) THEN 'Occupied'
        ELSE 'Available Now'
    END AS availability_status,
    
    -- Get next available date
    ISNULL(
        (SELECT MIN(check_out_date) 
         FROM RESERVATIONS res 
         WHERE res.room_id = r.room_id 
         AND res.status IN ('Confirmed', 'CheckedIn')
         AND res.check_out_date > CAST(GETDATE() AS DATE)),
        CAST(GETDATE() AS DATE)
    ) AS next_available_date,
    
    -- Count upcoming reservations
    (SELECT COUNT(*) 
     FROM RESERVATIONS res 
     WHERE res.room_id = r.room_id 
     AND res.status IN ('Confirmed', 'Pending')
     AND res.check_in_date > CAST(GETDATE() AS DATE)
    ) AS upcoming_reservations,
    
    -- Average rating for this room
    ISNULL(
        (SELECT AVG(CAST(rating AS DECIMAL(3,2))) 
         FROM REVIEWS rev 
         WHERE rev.room_id = r.room_id),
        0
    ) AS average_rating,
    
    -- Number of reviews
    (SELECT COUNT(*) FROM REVIEWS rev WHERE rev.room_id = r.room_id) AS review_count

FROM ROOMS r
INNER JOIN ROOM_TYPES rt ON r.type_id = rt.type_id
WHERE r.is_active = 1 AND rt.is_active = 1;
GO

-- =============================================
-- VIEW 2: vw_occupancy_statistics
-- Daily/monthly occupancy rates and revenue
-- per available room (RevPAR)
-- =============================================
CREATE OR ALTER VIEW vw_occupancy_statistics
AS
WITH DateRange AS (
    -- Generate dates for last 30 days
    SELECT CAST(DATEADD(DAY, -29, GETDATE()) AS DATE) AS report_date
    UNION ALL
    SELECT DATEADD(DAY, 1, report_date)
    FROM DateRange
    WHERE report_date < CAST(GETDATE() AS DATE)
),
DailyStats AS (
    SELECT 
        dr.report_date,
        
        -- Total rooms
        (SELECT COUNT(*) FROM ROOMS WHERE is_active = 1) AS total_rooms,
        
        -- Occupied rooms (reservations where status is CheckedIn or the date falls within stay)
        (SELECT COUNT(DISTINCT r.room_id)
         FROM RESERVATIONS res
         INNER JOIN ROOMS r ON res.room_id = r.room_id
         WHERE r.is_active = 1
         AND res.status IN ('CheckedIn', 'CheckedOut')
         AND dr.report_date BETWEEN res.check_in_date AND DATEADD(DAY, -1, res.check_out_date)
        ) AS occupied_rooms,
        
        -- Revenue for the day
        ISNULL(
            (SELECT SUM(res.room_charge / DATEDIFF(DAY, res.check_in_date, res.check_out_date))
             FROM RESERVATIONS res
             WHERE res.status IN ('CheckedIn', 'CheckedOut')
             AND dr.report_date BETWEEN res.check_in_date AND DATEADD(DAY, -1, res.check_out_date)),
            0
        ) AS daily_room_revenue,
        
        -- Service revenue for the day
        ISNULL(
            (SELECT SUM(su.total_price)
             FROM SERVICES_USED su
             WHERE CAST(su.used_date AS DATE) = dr.report_date
             AND su.status = 'Completed'),
            0
        ) AS daily_service_revenue
        
    FROM DateRange dr
)
SELECT 
    report_date,
    total_rooms,
    occupied_rooms,
    (total_rooms - occupied_rooms) AS available_rooms,
    
    -- Occupancy Rate
    CASE 
        WHEN total_rooms > 0 
        THEN CAST(ROUND((CAST(occupied_rooms AS DECIMAL(10,2)) / total_rooms) * 100, 2) AS DECIMAL(5,2))
        ELSE 0 
    END AS occupancy_rate_percent,
    
    daily_room_revenue,
    daily_service_revenue,
    (daily_room_revenue + daily_service_revenue) AS total_daily_revenue,
    
    -- RevPAR (Revenue Per Available Room)
    CASE 
        WHEN total_rooms > 0 
        THEN CAST(ROUND(daily_room_revenue / total_rooms, 2) AS DECIMAL(10,2))
        ELSE 0 
    END AS RevPAR,
    
    -- ADR (Average Daily Rate) - Revenue per occupied room
    CASE 
        WHEN occupied_rooms > 0 
        THEN CAST(ROUND(daily_room_revenue / occupied_rooms, 2) AS DECIMAL(10,2))
        ELSE 0 
    END AS ADR,
    
    -- Day of week for analysis
    DATENAME(WEEKDAY, report_date) AS day_of_week,
    
    -- Month for grouping
    DATENAME(MONTH, report_date) + ' ' + CAST(YEAR(report_date) AS NVARCHAR) AS month_year

FROM DailyStats
OPTION (MAXRECURSION 30);
GO

PRINT 'Member 1 Views created successfully.';
GO
