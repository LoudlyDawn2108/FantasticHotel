-- Khanh: FUNCTIONS (Simplified)
USE HotelManagement;
GO

-- fn_calculate_total_bill: Get bill details for reservation
CREATE OR ALTER FUNCTION fn_calculate_total_bill(@res_id INT)
RETURNS TABLE AS RETURN (
    SELECT r.reservation_id, r.customer_id,
        c.first_name + ' ' + c.last_name AS customer_name,
        rm.room_number, r.room_charge,
        ISNULL((SELECT SUM(total_price) FROM SERVICES_USED WHERE reservation_id = r.reservation_id), 0) AS service_charge,
        r.discount_amount, r.tax_amount, r.total_amount,
        r.paid_amount, r.total_amount - r.paid_amount AS balance_due,
        CASE WHEN r.paid_amount >= r.total_amount THEN 'Paid' 
             WHEN r.paid_amount > 0 THEN 'Partial' ELSE 'Unpaid' END AS payment_status
    FROM RESERVATIONS r
    JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    JOIN ROOMS rm ON r.room_id = rm.room_id
    WHERE r.reservation_id = @res_id
);
GO

-- fn_calculate_loyalty_points: Points based on amount and tier
CREATE OR ALTER FUNCTION fn_calculate_loyalty_points(@amount DECIMAL(10,2), @tier NVARCHAR(20))
RETURNS INT AS
BEGIN
    DECLARE @base INT = FLOOR(@amount / 10); -- 1 point per $10
    DECLARE @mult DECIMAL(3,2) = CASE @tier WHEN 'Platinum' THEN 2.0 WHEN 'Gold' THEN 1.5 WHEN 'Silver' THEN 1.25 ELSE 1.0 END;
    RETURN FLOOR(@base * @mult) + CASE WHEN @amount >= 1000 THEN 100 WHEN @amount >= 500 THEN 50 ELSE 0 END;
END;
GO

-- fn_get_customer_tier: Tier based on spending
CREATE OR ALTER FUNCTION fn_get_customer_tier(@spending DECIMAL(15,2))
RETURNS NVARCHAR(20) AS
BEGIN
    RETURN CASE WHEN @spending >= 50000 THEN 'Platinum' WHEN @spending >= 20000 THEN 'Gold'
                WHEN @spending >= 5000 THEN 'Silver' ELSE 'Bronze' END;
END;
GO
