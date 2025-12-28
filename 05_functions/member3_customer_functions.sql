-- =============================================
-- MEMBER 3: CUSTOMER & SERVICE MANAGEMENT
-- FUNCTIONS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION 1: fn_get_customer_tier (already created by Member 2, but included here for reference)
-- Returns customer's membership tier based on total spending
-- =============================================
-- Note: This function was already created in member2_payment_functions.sql
-- If not created, use the following:
IF OBJECT_ID('dbo.fn_get_customer_tier') IS NULL
BEGIN
    EXEC('
    CREATE FUNCTION fn_get_customer_tier
    (
        @total_spending DECIMAL(15,2)
    )
    RETURNS NVARCHAR(20)
    AS
    BEGIN
        DECLARE @tier NVARCHAR(20);
        
        SET @tier = 
            CASE 
                WHEN @total_spending >= 50000 THEN ''Platinum''
                WHEN @total_spending >= 20000 THEN ''Gold''
                WHEN @total_spending >= 5000 THEN ''Silver''
                ELSE ''Bronze''
            END;
        
        RETURN @tier;
    END
    ');
END
GO

-- =============================================
-- FUNCTION 2: fn_get_customer_discount_rate
-- Returns applicable discount rate based on
-- tier and booking value
-- =============================================
CREATE OR ALTER FUNCTION fn_get_customer_discount_rate
(
    @customer_id INT,
    @booking_value DECIMAL(10,2)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @tier NVARCHAR(20);
    DECLARE @base_discount DECIMAL(5,2);
    DECLARE @loyalty_points INT;
    DECLARE @additional_discount DECIMAL(5,2) = 0;
    DECLARE @total_discount DECIMAL(5,2);
    
    -- Get customer tier and loyalty points
    SELECT 
        @tier = membership_tier,
        @loyalty_points = loyalty_points
    FROM CUSTOMERS
    WHERE customer_id = @customer_id;
    
    -- If customer not found, return 0
    IF @tier IS NULL
        RETURN 0;
    
    -- Base discount by tier
    SET @base_discount = 
        CASE @tier
            WHEN 'Platinum' THEN 15.00
            WHEN 'Gold' THEN 10.00
            WHEN 'Silver' THEN 5.00
            WHEN 'Bronze' THEN 0.00
            ELSE 0.00
        END;
    
    -- Additional discount for loyalty points (1% per 1000 points, max 5%)
    SET @additional_discount = CASE 
        WHEN @loyalty_points >= 5000 THEN 5.00
        ELSE FLOOR(@loyalty_points / 1000)
    END;
    
    -- Bonus discount for high-value bookings
    IF @booking_value >= 1000
        SET @additional_discount = @additional_discount + 2.00;
    ELSE IF @booking_value >= 500
        SET @additional_discount = @additional_discount + 1.00;
    
    -- Calculate total discount (capped at 25%)
    SET @total_discount = @base_discount + @additional_discount;
    IF @total_discount > 25.00
        SET @total_discount = 25.00;
    
    RETURN @total_discount;
END;
GO

-- =============================================
-- FUNCTION 3: fn_get_customer_statistics
-- Returns a table with comprehensive customer statistics
-- =============================================
CREATE OR ALTER FUNCTION fn_get_customer_statistics
(
    @customer_id INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        c.customer_id,
        c.first_name + ' ' + c.last_name AS customer_name,
        c.email,
        c.membership_tier,
        c.loyalty_points,
        c.total_spending,
        DATEDIFF(DAY, c.created_at, GETDATE()) AS days_as_member,
        
        -- Reservation counts
        (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id) AS total_reservations,
        (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS completed_stays,
        (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id AND r.status = 'Cancelled') AS cancellations,
        
        -- Calculate cancellation rate
        CASE 
            WHEN (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id) > 0
            THEN CAST(
                (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id AND r.status = 'Cancelled') * 100.0 /
                (SELECT COUNT(*) FROM RESERVATIONS r WHERE r.customer_id = c.customer_id)
                AS DECIMAL(5,2))
            ELSE 0
        END AS cancellation_rate,
        
        -- Total nights stayed
        (SELECT ISNULL(SUM(DATEDIFF(DAY, r.check_in_date, r.check_out_date)), 0) 
         FROM RESERVATIONS r 
         WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS total_nights,
        
        -- Average stay duration
        (SELECT ISNULL(AVG(DATEDIFF(DAY, r.check_in_date, r.check_out_date)), 0) 
         FROM RESERVATIONS r 
         WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS avg_stay_nights,
        
        -- Favorite room type
        (SELECT TOP 1 rt.type_name 
         FROM RESERVATIONS r 
         INNER JOIN ROOMS rm ON r.room_id = rm.room_id
         INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
         WHERE r.customer_id = c.customer_id 
         GROUP BY rt.type_name 
         ORDER BY COUNT(*) DESC) AS favorite_room_type,
        
        -- Services usage
        (SELECT ISNULL(SUM(su.total_price), 0) 
         FROM SERVICES_USED su 
         INNER JOIN RESERVATIONS r ON su.reservation_id = r.reservation_id
         WHERE r.customer_id = c.customer_id) AS total_service_spending,
        
        -- Average rating given
        (SELECT ISNULL(AVG(CAST(rv.rating AS DECIMAL(3,2))), 0) 
         FROM REVIEWS rv 
         WHERE rv.customer_id = c.customer_id) AS avg_rating_given,
        
        -- Last visit
        (SELECT MAX(r.check_out_date) 
         FROM RESERVATIONS r 
         WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS last_visit_date,
        
        -- Customer value score (custom metric)
        CAST(
            (c.total_spending / 1000) +  -- $1000 = 1 point
            (c.loyalty_points / 100) +    -- 100 points = 1 score
            ((SELECT COUNT(*) FROM REVIEWS rv WHERE rv.customer_id = c.customer_id) * 5)  -- Each review = 5 points
            AS DECIMAL(10,2)
        ) AS customer_value_score
        
    FROM CUSTOMERS c
    WHERE c.customer_id = @customer_id
);
GO

PRINT 'Member 3 Functions created successfully.';
GO
