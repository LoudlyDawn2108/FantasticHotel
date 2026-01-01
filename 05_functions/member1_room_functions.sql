-- =============================================
-- Phuc: RESERVATION & ROOM MANAGEMENT
-- FUNCTIONS
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION 1: fn_calculate_room_price
-- Calculates total room price with seasonal rates,
-- weekday/weekend pricing, and membership discounts
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_room_price
(
    @room_id INT,
    @check_in_date DATE,
    @check_out_date DATE,
    @customer_id INT = NULL
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @total_price DECIMAL(10,2) = 0;
    DECLARE @base_price DECIMAL(10,2);
    DECLARE @current_date DATE;
    DECLARE @daily_rate DECIMAL(10,2);
    DECLARE @seasonal_multiplier DECIMAL(5,2);
    DECLARE @weekend_multiplier DECIMAL(5,2);
    
    -- Get base price for the room type
    SELECT @base_price = rt.base_price
    FROM ROOMS r
    INNER JOIN ROOM_TYPES rt ON r.type_id = rt.type_id
    WHERE r.room_id = @room_id;
    
    -- If room not found, return 0
    IF @base_price IS NULL
        RETURN 0;
    
    -- Calculate price for each night
    SET @current_date = @check_in_date;
    
    WHILE @current_date < @check_out_date
    BEGIN
        SET @daily_rate = @base_price;
        
        -- Apply seasonal pricing
        -- High Season: December, June, July, August (20% increase)
        -- Low Season: January, February, November (10% decrease)
        -- Regular: Other months
        SET @seasonal_multiplier = 
            CASE MONTH(@current_date)
                WHEN 12 THEN 1.20  -- December (Holiday)
                WHEN 6 THEN 1.20   -- June (Summer)
                WHEN 7 THEN 1.20   -- July (Summer)
                WHEN 8 THEN 1.20   -- August (Summer)
                WHEN 1 THEN 0.90   -- January (Low)
                WHEN 2 THEN 0.90   -- February (Low)
                WHEN 11 THEN 0.90  -- November (Low)
                ELSE 1.00          -- Regular
            END;
        
        -- Apply weekend pricing (Friday and Saturday nights are 15% more)
        SET @weekend_multiplier = 
            CASE DATEPART(WEEKDAY, @current_date)
                WHEN 6 THEN 1.15  -- Friday
                WHEN 7 THEN 1.15  -- Saturday
                ELSE 1.00
            END;
        
        -- Calculate daily rate with multipliers
        SET @daily_rate = @daily_rate * @seasonal_multiplier * @weekend_multiplier;
        
        -- Add to total
        SET @total_price = @total_price + @daily_rate;
        
        -- Move to next day
        SET @current_date = DATEADD(DAY, 1, @current_date);
    END
    
    RETURN ROUND(@total_price, 2);
END;
GO

-- =============================================
-- FUNCTION 2: fn_check_room_availability
-- Returns 1 if room is available for the date range,
-- 0 if not available
-- =============================================
CREATE OR ALTER FUNCTION fn_check_room_availability
(
    @room_id INT,
    @check_in_date DATE,
    @check_out_date DATE
)
RETURNS BIT
AS
BEGIN
    DECLARE @is_available BIT = 1;
    DECLARE @room_status NVARCHAR(20);
    
    -- Check if room exists and is active
    SELECT @room_status = status
    FROM ROOMS
    WHERE room_id = @room_id AND is_active = 1;
    
    IF @room_status IS NULL
        RETURN 0;  -- Room doesn't exist or is inactive
    
    -- Check if room is in maintenance
    IF @room_status = 'Maintenance'
        RETURN 0;
    
    -- Check for overlapping reservations
    -- A reservation overlaps if:
    -- (existing check-in < new check-out) AND (existing check-out > new check-in)
    IF EXISTS (
        SELECT 1 
        FROM RESERVATIONS
        WHERE room_id = @room_id
        AND status IN ('Pending', 'Confirmed', 'CheckedIn')
        AND check_in_date < @check_out_date
        AND check_out_date > @check_in_date
    )
    BEGIN
        SET @is_available = 0;
    END
    
    RETURN @is_available;
END;
GO

-- =============================================
-- Additional helper function for discount calculation
-- (Used by sp_create_reservation)
-- =============================================
CREATE OR ALTER FUNCTION fn_calculate_discount_rate
(
    @membership_tier NVARCHAR(20),
    @booking_amount DECIMAL(10,2)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @discount_rate DECIMAL(5,2) = 0;
    
    -- Base discount by tier
    SET @discount_rate = 
        CASE @membership_tier
            WHEN 'Platinum' THEN 15.00
            WHEN 'Gold' THEN 10.00
            WHEN 'Silver' THEN 5.00
            WHEN 'Bronze' THEN 0.00
            ELSE 0.00
        END;
    
    -- Additional discount for high-value bookings
    IF @booking_amount >= 1000
        SET @discount_rate = @discount_rate + 2.00;
    ELSE IF @booking_amount >= 500
        SET @discount_rate = @discount_rate + 1.00;
    
    -- Cap discount at 20%
    IF @discount_rate > 20.00
        SET @discount_rate = 20.00;
    
    RETURN @discount_rate;
END;
GO

PRINT 'Phuc Functions created successfully.';
GO
