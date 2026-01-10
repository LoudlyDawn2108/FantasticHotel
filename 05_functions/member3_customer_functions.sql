-- Ninh: FUNCTIONS (Simplified)
USE HotelManagement;
GO

-- fn_get_customer_discount_rate: Discount based on tier and points
CREATE OR ALTER FUNCTION fn_get_customer_discount_rate(@cust_id INT, @amount DECIMAL(10,2))
RETURNS DECIMAL(5,2) AS
BEGIN
    DECLARE @tier NVARCHAR(20), @points INT, @rate DECIMAL(5,2);
    SELECT @tier = membership_tier, @points = loyalty_points FROM CUSTOMERS WHERE customer_id = @cust_id;
    IF @tier IS NULL RETURN 0;
    
    SET @rate = CASE @tier WHEN 'Platinum' THEN 15 WHEN 'Gold' THEN 10 WHEN 'Silver' THEN 5 ELSE 0 END;
    SET @rate = @rate + CASE WHEN @points >= 5000 THEN 5 ELSE FLOOR(@points / 1000) END;
    IF @amount >= 1000 SET @rate = @rate + 2;
    RETURN CASE WHEN @rate > 25 THEN 25 ELSE @rate END;
END;
GO

-- fn_get_customer_statistics: Customer stats table function
CREATE OR ALTER FUNCTION fn_get_customer_statistics(@cust_id INT)
RETURNS TABLE AS RETURN (
    SELECT c.customer_id, c.first_name + ' ' + c.last_name AS name, c.membership_tier, c.loyalty_points, c.total_spending,
        (SELECT COUNT(*) FROM RESERVATIONS WHERE customer_id = c.customer_id) AS reservations,
        (SELECT COUNT(*) FROM RESERVATIONS WHERE customer_id = c.customer_id AND status = 'CheckedOut') AS completed,
        (SELECT ISNULL(SUM(total_price),0) FROM SERVICES_USED su 
            JOIN RESERVATIONS r ON su.reservation_id = r.reservation_id WHERE r.customer_id = c.customer_id) AS service_spend
    FROM CUSTOMERS c WHERE c.customer_id = @cust_id
);
GO
