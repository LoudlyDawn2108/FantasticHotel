-- =============================================
-- Khanh: PAYMENT & FINANCIAL MANAGEMENT
-- FUNCTIONS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION 1: fn_calculate_total_bill
-- Calculates total bill including room, services,
-- taxes, and discounts for a reservation
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_total_bill
(
    @reservation_id INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        r.reservation_id,
        r.customer_id,
        c.first_name + ' ' + c.last_name AS customer_name,
        rm.room_number,
        rt.type_name AS room_type,
        
        -- Dates and duration
        r.check_in_date,
        r.check_out_date,
        DATEDIFF(DAY, r.check_in_date, r.check_out_date) AS num_nights,
        
        -- Room charges
        r.room_charge,
        
        -- Service charges (calculated from SERVICES_USED)
        ISNULL(
            (SELECT SUM(su.total_price) 
             FROM SERVICES_USED su 
             WHERE su.reservation_id = r.reservation_id 
             AND su.status = 'Completed'),
            0
        ) AS calculated_service_charge,
        
        -- Subtotal
        r.room_charge + ISNULL(
            (SELECT SUM(su.total_price) 
             FROM SERVICES_USED su 
             WHERE su.reservation_id = r.reservation_id 
             AND su.status = 'Completed'),
            0
        ) AS subtotal,
        
        -- Discount
        r.discount_amount,
        
        -- Tax (10% on subtotal after discount)
        CAST(
            (r.room_charge + ISNULL(
                (SELECT SUM(su.total_price) 
                 FROM SERVICES_USED su 
                 WHERE su.reservation_id = r.reservation_id 
                 AND su.status = 'Completed'),
                0
            ) - r.discount_amount) * 0.10 AS DECIMAL(10,2)
        ) AS calculated_tax,
        
        -- Total
        CAST(
            (r.room_charge + ISNULL(
                (SELECT SUM(su.total_price) 
                 FROM SERVICES_USED su 
                 WHERE su.reservation_id = r.reservation_id 
                 AND su.status = 'Completed'),
                0
            ) - r.discount_amount) * 1.10 AS DECIMAL(10,2)
        ) AS calculated_total,
        
        -- Payment status
        r.paid_amount,
        r.total_amount - r.paid_amount AS balance_due,
        
        CASE 
            WHEN r.paid_amount >= r.total_amount THEN 'Paid in Full'
            WHEN r.paid_amount > 0 THEN 'Partially Paid'
            ELSE 'Unpaid'
        END AS payment_status,
        
        -- Service count
        (SELECT COUNT(*) FROM SERVICES_USED su 
         WHERE su.reservation_id = r.reservation_id 
         AND su.status = 'Completed') AS service_count

    FROM RESERVATIONS r
    INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    INNER JOIN ROOMS rm ON r.room_id = rm.room_id
    INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
    WHERE r.reservation_id = @reservation_id
);
GO

-- =============================================
-- FUNCTION 2: fn_calculate_loyalty_points
-- Returns loyalty points earned based on amount
-- and membership tier
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_loyalty_points
(
    @amount DECIMAL(10,2),
    @membership_tier NVARCHAR(20)
)
RETURNS INT
AS
BEGIN
    DECLARE @base_points INT;
    DECLARE @tier_multiplier DECIMAL(3,2);
    DECLARE @total_points INT;
    
    -- Base calculation: 1 point per $10 spent
    SET @base_points = FLOOR(@amount / 10);
    
    -- Tier multiplier for bonus points
    SET @tier_multiplier = 
        CASE @membership_tier
            WHEN 'Platinum' THEN 2.00  -- Double points
            WHEN 'Gold' THEN 1.50      -- 50% bonus
            WHEN 'Silver' THEN 1.25    -- 25% bonus
            WHEN 'Bronze' THEN 1.00    -- No bonus
            ELSE 1.00
        END;
    
    -- Calculate total points
    SET @total_points = FLOOR(@base_points * @tier_multiplier);
    
    -- Bonus points for large transactions
    IF @amount >= 1000
        SET @total_points = @total_points + 100;  -- Bonus 100 points
    ELSE IF @amount >= 500
        SET @total_points = @total_points + 50;   -- Bonus 50 points
    ELSE IF @amount >= 200
        SET @total_points = @total_points + 20;   -- Bonus 20 points
    
    RETURN @total_points;
END;
GO

-- =============================================
-- FUNCTION 3: fn_get_customer_tier
-- Returns the membership tier based on total spending
-- (Helper function for triggers)
-- =============================================
CREATE OR ALTER FUNCTION fn_get_customer_tier
(
    @total_spending DECIMAL(15,2)
)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @tier NVARCHAR(20);
    
    -- Tier thresholds based on total spending
    SET @tier = 
        CASE 
            WHEN @total_spending >= 50000 THEN 'Platinum'  -- $50,000+
            WHEN @total_spending >= 20000 THEN 'Gold'      -- $20,000+
            WHEN @total_spending >= 5000 THEN 'Silver'     -- $5,000+
            ELSE 'Bronze'                                   -- Under $5,000
        END;
    
    RETURN @tier;
END;
GO

PRINT 'Khanh Functions created successfully.';
GO
