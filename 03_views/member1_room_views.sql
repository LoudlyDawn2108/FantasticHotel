-- Phuc: VIEWS (Simplified)
USE HotelManagement;
GO

-- vw_room_availability: Room status and availability
CREATE OR ALTER VIEW vw_room_availability AS
SELECT r.room_id, r.room_number, r.floor, rt.type_name, rt.base_price, rt.capacity, r.status,
    CASE WHEN r.status IN ('Maintenance','Cleaning') THEN 'Not Available'
         WHEN EXISTS (SELECT 1 FROM RESERVATIONS res WHERE res.room_id = r.room_id 
            AND res.status IN ('Confirmed','CheckedIn')
            AND GETDATE() BETWEEN res.check_in_date AND res.check_out_date) THEN 'Occupied'
         ELSE 'Available' END AS availability,
    (SELECT COUNT(*) FROM RESERVATIONS res WHERE res.room_id = r.room_id 
        AND res.status IN ('Confirmed','Pending') AND res.check_in_date > GETDATE()) AS upcoming
FROM ROOMS r JOIN ROOM_TYPES rt ON r.type_id = rt.type_id WHERE r.is_active = 1;
GO

-- vw_occupancy_statistics: Daily occupancy rates
CREATE OR ALTER VIEW vw_occupancy_statistics AS
SELECT CAST(GETDATE() AS DATE) AS report_date,
    (SELECT COUNT(*) FROM ROOMS WHERE is_active = 1) AS total_rooms,
    (SELECT COUNT(*) FROM RESERVATIONS WHERE status = 'CheckedIn') AS occupied,
    CAST((SELECT COUNT(*) FROM RESERVATIONS WHERE status = 'CheckedIn') * 100.0 / 
        NULLIF((SELECT COUNT(*) FROM ROOMS WHERE is_active = 1), 0) AS DECIMAL(5,2)) AS occupancy_pct,
    (SELECT SUM(total_amount) FROM RESERVATIONS WHERE status = 'CheckedIn') AS total_revenue;
GO
