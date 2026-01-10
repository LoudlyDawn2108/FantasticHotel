-- Phuc: FUNCTIONS (Simplified)
USE HotelManagement;
GO

-- fn_calculate_room_price: Calculate room price with seasonal/weekend rates
CREATE OR ALTER FUNCTION fn_calculate_room_price
(@room_id INT, @checkin DATE, @checkout DATE)
RETURNS DECIMAL(10,2) AS
BEGIN
    DECLARE @total DECIMAL(10,2) = 0, @base DECIMAL(10,2), @date DATE = @checkin;
    SELECT @base = rt.base_price FROM ROOMS r JOIN ROOM_TYPES rt ON r.type_id = rt.type_id WHERE r.room_id = @room_id;
    IF @base IS NULL RETURN 0;
    
    WHILE @date < @checkout
    BEGIN
        -- Seasonal: Dec/Jun/Jul/Aug=+20%, Jan/Feb/Nov=-10%
        -- Weekend: Fri/Sat=+15%
        SET @total = @total + @base * 
            CASE MONTH(@date) WHEN 12 THEN 1.2 WHEN 6 THEN 1.2 WHEN 7 THEN 1.2 WHEN 8 THEN 1.2
                WHEN 1 THEN 0.9 WHEN 2 THEN 0.9 WHEN 11 THEN 0.9 ELSE 1.0 END *
            CASE DATEPART(WEEKDAY,@date) WHEN 6 THEN 1.15 WHEN 7 THEN 1.15 ELSE 1.0 END;
        SET @date = DATEADD(DAY, 1, @date);
    END
    RETURN ROUND(@total, 2);
END;
GO

-- fn_check_room_availability: Returns 1 if available, 0 if not
CREATE OR ALTER FUNCTION fn_check_room_availability
(@room_id INT, @checkin DATE, @checkout DATE)
RETURNS BIT AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ROOMS WHERE room_id = @room_id AND is_active = 1 AND status <> 'Maintenance')
        RETURN 0;
    IF EXISTS (SELECT 1 FROM RESERVATIONS WHERE room_id = @room_id 
        AND status IN ('Pending','Confirmed','CheckedIn')
        AND check_in_date < @checkout AND check_out_date > @checkin)
        RETURN 0;
    RETURN 1;
END;
GO

-- fn_calculate_discount_rate: Tier-based discount
CREATE OR ALTER FUNCTION fn_calculate_discount_rate(@tier NVARCHAR(20), @amount DECIMAL(10,2))
RETURNS DECIMAL(5,2) AS
BEGIN
    DECLARE @rate DECIMAL(5,2) = CASE @tier WHEN 'Platinum' THEN 15 WHEN 'Gold' THEN 10 WHEN 'Silver' THEN 5 ELSE 0 END;
    IF @amount >= 1000 SET @rate = @rate + 2;
    RETURN @rate;
END;
GO
