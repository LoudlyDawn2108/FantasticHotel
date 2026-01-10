-- =============================================
-- Ninh: CUSTOMER & SERVICE MANAGEMENT
-- FUNCTIONS (SIMPLIFIED)
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION 1: fn_get_customer_tier
-- Returns membership tier based on total spending
-- =============================================
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
        RETURN CASE 
            WHEN @total_spending >= 50000 THEN ''Platinum''
            WHEN @total_spending >= 20000 THEN ''Gold''
            WHEN @total_spending >= 5000 THEN ''Silver''
            ELSE ''Bronze''
        END;
    END
    ');
END
GO

-- =============================================
-- FUNCTION 2: fn_get_customer_discount_rate
-- Returns discount rate based on tier
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
    
    -- Get customer tier
    SELECT @tier = membership_tier
    FROM CUSTOMERS
    WHERE customer_id = @customer_id;
    
    -- Return tier-based discount
    RETURN CASE @tier
        WHEN 'Platinum' THEN 15.00
        WHEN 'Gold' THEN 10.00
        WHEN 'Silver' THEN 5.00
        ELSE 0.00
    END;
END;
GO

-- =============================================
-- FUNCTION 3: fn_get_customer_statistics
-- Returns table with customer statistics
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
        
        -- Total nights stayed
        (SELECT ISNULL(SUM(DATEDIFF(DAY, r.check_in_date, r.check_out_date)), 0) 
         FROM RESERVATIONS r 
         WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS total_nights,
        
        -- Favorite room type
        (SELECT TOP 1 rt.type_name 
         FROM RESERVATIONS r 
         INNER JOIN ROOMS rm ON r.room_id = rm.room_id
         INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
         WHERE r.customer_id = c.customer_id 
         GROUP BY rt.type_name 
         ORDER BY COUNT(*) DESC) AS favorite_room_type,
        
        -- Last visit
        (SELECT MAX(r.check_out_date) 
         FROM RESERVATIONS r 
         WHERE r.customer_id = c.customer_id AND r.status = 'CheckedOut') AS last_visit_date
        
    FROM CUSTOMERS c
    WHERE c.customer_id = @customer_id
);
GO

PRINT 'Ninh Functions created successfully.';
GO
