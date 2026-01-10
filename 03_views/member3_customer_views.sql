-- Ninh: VIEWS (Simplified)
USE HotelManagement;
GO

-- vw_customer_history: Customer stats and history
CREATE OR ALTER VIEW vw_customer_history AS
SELECT c.customer_id, c.first_name + ' ' + c.last_name AS name, c.email, c.membership_tier,
    c.loyalty_points, c.total_spending,
    (SELECT COUNT(*) FROM RESERVATIONS WHERE customer_id = c.customer_id) AS reservations,
    (SELECT COUNT(*) FROM RESERVATIONS WHERE customer_id = c.customer_id AND status = 'CheckedOut') AS stays,
    (SELECT ISNULL(SUM(su.total_price),0) FROM SERVICES_USED su 
        JOIN RESERVATIONS r ON su.reservation_id = r.reservation_id 
        WHERE r.customer_id = c.customer_id) AS service_spend
FROM CUSTOMERS c WHERE c.is_active = 1;
GO

-- vw_popular_services: Service popularity ranking
CREATE OR ALTER VIEW vw_popular_services AS
SELECT s.service_id, s.service_name, sc.category_name, s.price,
    COUNT(*) AS usage_count, SUM(su.total_price) AS revenue
FROM SERVICES_USED su
JOIN SERVICES s ON su.service_id = s.service_id
JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
WHERE su.status = 'Completed'
GROUP BY s.service_id, s.service_name, sc.category_name, s.price;
GO
