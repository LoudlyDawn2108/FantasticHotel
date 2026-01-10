-- =============================================
-- HOTEL MANAGEMENT SYSTEM - SAMPLE DATA
-- SQL Server Implementation
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- LOOKUP DATA
-- =============================================

-- Insert Departments
INSERT INTO DEPARTMENTS (department_name, description) VALUES
('Front Desk', 'Reception and guest services'),
('Housekeeping', 'Room cleaning and maintenance'),
('Food & Beverage', 'Restaurant and room service'),
('Maintenance', 'Building and equipment maintenance'),
('Security', 'Hotel security services'),
('Management', 'Hotel administration');
GO

-- Insert Service Categories
INSERT INTO SERVICE_CATEGORIES (category_name, description) VALUES
('Room Service', 'In-room dining and amenities'),
('Spa & Wellness', 'Spa treatments and fitness'),
('Laundry', 'Laundry and dry cleaning services'),
('Transportation', 'Airport transfers and car rental'),
('Entertainment', 'Tours and recreational activities'),
('Business', 'Conference rooms and business services');
GO

-- Insert Room Types
INSERT INTO ROOM_TYPES (type_name, description, base_price, capacity, amenities) VALUES
('Standard', 'Comfortable room with essential amenities', 100.00, 2, 'TV, WiFi, Air Conditioning, Mini Fridge'),
('Superior', 'Spacious room with city view', 150.00, 2, 'TV, WiFi, Air Conditioning, Mini Bar, City View'),
('Deluxe', 'Luxury room with premium amenities', 220.00, 3, 'Smart TV, High-Speed WiFi, AC, Mini Bar, Bathtub, City View'),
('Suite', 'Separate living area with bedroom', 350.00, 4, 'Smart TV, High-Speed WiFi, AC, Full Bar, Jacuzzi, Panoramic View'),
('Presidential Suite', 'Ultimate luxury experience', 800.00, 6, 'Multiple TVs, Premium WiFi, Climate Control, Full Bar, Private Pool, Butler Service');
GO

-- =============================================
-- ROOMS DATA
-- =============================================

-- Floor 1: Standard Rooms (101-110)
INSERT INTO ROOMS (room_number, type_id, floor, status) VALUES
('101', 1, 1, 'Available'),
('102', 1, 1, 'Available'),
('103', 1, 1, 'Occupied'),
('104', 1, 1, 'Available'),
('105', 1, 1, 'Maintenance'),
('106', 1, 1, 'Available'),
('107', 1, 1, 'Cleaning'),
('108', 1, 1, 'Available'),
('109', 1, 1, 'Available'),
('110', 1, 1, 'Reserved');

-- Floor 2: Superior Rooms (201-210)
INSERT INTO ROOMS (room_number, type_id, floor, status) VALUES
('201', 2, 2, 'Available'),
('202', 2, 2, 'Occupied'),
('203', 2, 2, 'Available'),
('204', 2, 2, 'Available'),
('205', 2, 2, 'Reserved'),
('206', 2, 2, 'Available'),
('207', 2, 2, 'Available'),
('208', 2, 2, 'Cleaning'),
('209', 2, 2, 'Available'),
('210', 2, 2, 'Available');

-- Floor 3: Deluxe Rooms (301-308)
INSERT INTO ROOMS (room_number, type_id, floor, status) VALUES
('301', 3, 3, 'Available'),
('302', 3, 3, 'Occupied'),
('303', 3, 3, 'Available'),
('304', 3, 3, 'Available'),
('305', 3, 3, 'Available'),
('306', 3, 3, 'Reserved'),
('307', 3, 3, 'Available'),
('308', 3, 3, 'Maintenance');

-- Floor 4: Suites (401-404)
INSERT INTO ROOMS (room_number, type_id, floor, status) VALUES
('401', 4, 4, 'Available'),
('402', 4, 4, 'Occupied'),
('403', 4, 4, 'Available'),
('404', 4, 4, 'Available');

-- Floor 5: Presidential Suite (501)
INSERT INTO ROOMS (room_number, type_id, floor, status) VALUES
('501', 5, 5, 'Available');
GO

-- =============================================
-- EMPLOYEES DATA
-- =============================================

INSERT INTO EMPLOYEES (department_id, first_name, last_name, email, phone, position, salary, hire_date) VALUES
-- Front Desk
(1, 'Anna', 'Johnson', 'anna.johnson@hotel.com', '555-0101', 'Front Desk Manager', 4500.00, '2020-03-15'),
(1, 'Michael', 'Brown', 'michael.brown@hotel.com', '555-0102', 'Receptionist', 2800.00, '2021-06-20'),
(1, 'Sarah', 'Davis', 'sarah.davis@hotel.com', '555-0103', 'Receptionist', 2800.00, '2022-01-10'),
(1, 'David', 'Wilson', 'david.wilson@hotel.com', '555-0104', 'Night Auditor', 3000.00, '2021-09-05'),

-- Housekeeping
(2, 'Maria', 'Garcia', 'maria.garcia@hotel.com', '555-0201', 'Housekeeping Supervisor', 3500.00, '2019-08-12'),
(2, 'Carlos', 'Martinez', 'carlos.martinez@hotel.com', '555-0202', 'Room Attendant', 2200.00, '2022-04-18'),
(2, 'Linda', 'Anderson', 'linda.anderson@hotel.com', '555-0203', 'Room Attendant', 2200.00, '2022-07-25'),
(2, 'James', 'Taylor', 'james.taylor@hotel.com', '555-0204', 'Room Attendant', 2200.00, '2023-02-14'),

-- Food & Beverage
(3, 'Robert', 'Thomas', 'robert.thomas@hotel.com', '555-0301', 'F&B Manager', 5000.00, '2018-11-20'),
(3, 'Jennifer', 'White', 'jennifer.white@hotel.com', '555-0302', 'Chef', 4200.00, '2019-05-30'),
(3, 'William', 'Harris', 'william.harris@hotel.com', '555-0303', 'Waiter', 2500.00, '2021-12-08'),
(3, 'Lisa', 'Clark', 'lisa.clark@hotel.com', '555-0304', 'Bartender', 2800.00, '2022-03-22'),

-- Maintenance
(4, 'John', 'Lewis', 'john.lewis@hotel.com', '555-0401', 'Maintenance Manager', 4000.00, '2017-06-15'),
(4, 'Richard', 'Lee', 'richard.lee@hotel.com', '555-0402', 'Technician', 3200.00, '2020-09-10'),
(4, 'Thomas', 'Walker', 'thomas.walker@hotel.com', '555-0403', 'Technician', 3200.00, '2021-04-05'),

-- Security
(5, 'Daniel', 'Hall', 'daniel.hall@hotel.com', '555-0501', 'Security Manager', 3800.00, '2018-02-28'),
(5, 'Mark', 'Allen', 'mark.allen@hotel.com', '555-0502', 'Security Officer', 2600.00, '2020-10-15'),

-- Management
(6, 'Elizabeth', 'King', 'elizabeth.king@hotel.com', '555-0601', 'General Manager', 8000.00, '2015-01-10'),
(6, 'Christopher', 'Wright', 'christopher.wright@hotel.com', '555-0602', 'Assistant Manager', 5500.00, '2017-09-22');
GO

-- =============================================
-- SERVICES DATA
-- =============================================

INSERT INTO SERVICES (category_id, service_name, description, price, duration_minutes) VALUES
-- Room Service (category 1)
(1, 'Breakfast In Room', 'Continental or American breakfast delivered to room', 35.00, 30),
(1, 'Lunch In Room', 'Full lunch menu available for in-room dining', 45.00, 45),
(1, 'Dinner In Room', 'Gourmet dinner experience in your room', 75.00, 60),
(1, 'Mini Bar Refill', 'Restock mini bar items', 50.00, 15),
(1, 'Champagne Service', 'Premium champagne with glasses', 120.00, 15),

-- Spa & Wellness (category 2)
(2, 'Swedish Massage', 'Relaxing full-body massage', 90.00, 60),
(2, 'Deep Tissue Massage', 'Therapeutic deep muscle massage', 110.00, 60),
(2, 'Facial Treatment', 'Rejuvenating facial with premium products', 80.00, 45),
(2, 'Gym Access', 'Full day access to fitness center', 20.00, 480),
(2, 'Yoga Session', 'Private yoga session with instructor', 60.00, 60),

-- Laundry (category 3)
(3, 'Standard Laundry', 'Regular washing and folding', 25.00, 240),
(3, 'Express Laundry', 'Same-day laundry service', 45.00, 120),
(3, 'Dry Cleaning', 'Professional dry cleaning service', 35.00, 480),
(3, 'Ironing Service', 'Professional pressing and ironing', 15.00, 60),

-- Transportation (category 4)
(4, 'Airport Pickup', 'Luxury car airport transfer', 60.00, 60),
(4, 'Airport Drop-off', 'Luxury car to airport', 60.00, 60),
(4, 'City Tour', 'Half-day guided city tour', 150.00, 240),
(4, 'Car Rental', 'Daily car rental with driver', 200.00, 480),

-- Entertainment (category 5)
(5, 'Museum Tour', 'Guided tour to local museums', 80.00, 180),
(5, 'Night Club Access', 'VIP access to partner night club', 100.00, 300),
(5, 'Concert Tickets', 'Premium concert ticket arrangement', 150.00, 180),

-- Business (category 6)
(6, 'Meeting Room Small', 'Meeting room for up to 10 people (per hour)', 75.00, 60),
(6, 'Meeting Room Large', 'Conference room for up to 30 people (per hour)', 150.00, 60),
(6, 'Printing Service', 'Document printing (up to 50 pages)', 20.00, 15),
(6, 'Video Conference Setup', 'Full video conferencing equipment setup', 100.00, 30);
GO

-- =============================================
-- CUSTOMERS DATA
-- =============================================

INSERT INTO CUSTOMERS (first_name, last_name, email, phone, address, id_number, id_type, date_of_birth, nationality, loyalty_points, membership_tier, total_spending) VALUES
('John', 'Smith', 'john.smith@email.com', '555-1001', '123 Main St, New York, NY', 'P12345678', 'Passport', '1985-06-15', 'USA', 2500, 'Gold', 15000.00),
('Emily', 'Johnson', 'emily.johnson@email.com', '555-1002', '456 Oak Ave, Los Angeles, CA', 'ID87654321', 'ID Card', '1990-03-22', 'USA', 500, 'Bronze', 3500.00),
('Michael', 'Williams', 'michael.williams@email.com', '555-1003', '789 Pine Rd, Chicago, IL', 'DL11223344', 'Driver License', '1978-11-08', 'USA', 8000, 'Platinum', 45000.00),
('Sarah', 'Brown', 'sarah.brown@email.com', '555-1004', '321 Elm St, Houston, TX', 'P98765432', 'Passport', '1995-08-30', 'Canada', 1200, 'Silver', 8500.00),
('David', 'Jones', 'david.jones@email.com', '555-1005', '654 Maple Dr, Phoenix, AZ', 'ID55667788', 'ID Card', '1982-01-17', 'USA', 300, 'Bronze', 2100.00),
('Lisa', 'Garcia', 'lisa.garcia@email.com', '555-1006', '987 Cedar Ln, Philadelphia, PA', 'P11112222', 'Passport', '1988-09-25', 'Mexico', 4500, 'Gold', 28000.00),
('James', 'Miller', 'james.miller@email.com', '555-1007', '147 Birch Blvd, San Antonio, TX', 'DL33445566', 'Driver License', '1975-04-12', 'USA', 150, 'Bronze', 1200.00),
('Jennifer', 'Davis', 'jennifer.davis@email.com', '555-1008', '258 Walnut Way, San Diego, CA', 'P33334444', 'Passport', '1992-12-05', 'UK', 1800, 'Silver', 11000.00),
('Robert', 'Rodriguez', 'robert.rodriguez@email.com', '555-1009', '369 Cherry Ct, Dallas, TX', 'ID99001122', 'ID Card', '1980-07-20', 'Spain', 6500, 'Platinum', 38000.00),
('Michelle', 'Martinez', 'michelle.martinez@email.com', '555-1010', '480 Spruce St, San Jose, CA', 'P55556666', 'Passport', '1998-02-28', 'USA', 800, 'Silver', 5500.00),
('William', 'Anderson', 'william.anderson@email.com', '555-1011', '591 Ash Ave, Austin, TX', 'DL77889900', 'Driver License', '1970-10-10', 'USA', 10000, 'Platinum', 62000.00),
('Jessica', 'Taylor', 'jessica.taylor@email.com', '555-1012', '702 Poplar Pl, Jacksonville, FL', 'ID12341234', 'ID Card', '1993-05-18', 'Australia', 400, 'Bronze', 2800.00);
GO

-- =============================================
-- RESERVATIONS DATA
-- =============================================

-- Past Reservations (Completed)
INSERT INTO RESERVATIONS (customer_id, room_id, check_in_date, check_out_date, actual_check_in, actual_check_out, num_guests, status, room_charge, service_charge, tax_amount, discount_amount, total_amount, paid_amount) VALUES
(1, 3, '2024-10-01', '2024-10-05', '2024-10-01 14:30:00', '2024-10-05 11:00:00', 2, 'CheckedOut', 400.00, 85.00, 48.50, 20.00, 513.50, 513.50),
(2, 12, '2024-10-10', '2024-10-12', '2024-10-10 15:00:00', '2024-10-12 10:30:00', 1, 'CheckedOut', 300.00, 45.00, 34.50, 0.00, 379.50, 379.50),
(3, 22, '2024-10-15', '2024-10-20', '2024-10-15 13:45:00', '2024-10-20 11:30:00', 2, 'CheckedOut', 1100.00, 350.00, 145.00, 100.00, 1495.00, 1495.00),
(4, 28, '2024-11-01', '2024-11-04', '2024-11-01 16:00:00', '2024-11-04 09:45:00', 3, 'CheckedOut', 1050.00, 180.00, 123.00, 50.00, 1303.00, 1303.00),
(5, 1, '2024-11-10', '2024-11-11', '2024-11-10 14:15:00', '2024-11-11 10:00:00', 1, 'CheckedOut', 100.00, 0.00, 10.00, 0.00, 110.00, 110.00),
(6, 21, '2024-11-15', '2024-11-18', '2024-11-15 15:30:00', '2024-11-18 11:00:00', 2, 'CheckedOut', 660.00, 200.00, 86.00, 40.00, 906.00, 906.00);

-- Current Reservations (CheckedIn - matching occupied rooms)
INSERT INTO RESERVATIONS (customer_id, room_id, check_in_date, check_out_date, actual_check_in, num_guests, status, room_charge, service_charge, tax_amount, discount_amount, total_amount, paid_amount) VALUES
(7, 3, '2024-12-26', '2024-12-30', '2024-12-26 14:00:00', 2, 'CheckedIn', 400.00, 0.00, 40.00, 0.00, 440.00, 440.00),
(8, 12, '2024-12-27', '2024-12-29', '2024-12-27 15:30:00', 1, 'CheckedIn', 300.00, 0.00, 30.00, 0.00, 330.00, 330.00),
(9, 22, '2024-12-25', '2024-12-31', '2024-12-25 13:00:00', 2, 'CheckedIn', 1320.00, 120.00, 144.00, 100.00, 1484.00, 1000.00),
(10, 30, '2024-12-28', '2025-01-02', '2024-12-28 16:00:00', 4, 'CheckedIn', 1750.00, 0.00, 175.00, 0.00, 1925.00, 1925.00);

-- Upcoming Reservations (Confirmed - matching reserved rooms)
INSERT INTO RESERVATIONS (customer_id, room_id, check_in_date, check_out_date, num_guests, status, room_charge, total_amount) VALUES
(11, 10, '2024-12-30', '2025-01-03', 2, 'Confirmed', 400.00, 440.00),
(12, 15, '2024-12-31', '2025-01-02', 1, 'Confirmed', 300.00, 330.00),
(1, 26, '2025-01-05', '2025-01-08', 2, 'Confirmed', 660.00, 726.00);

-- Cancelled Reservation
INSERT INTO RESERVATIONS (customer_id, room_id, check_in_date, check_out_date, num_guests, status, room_charge, total_amount, cancellation_reason, cancelled_at) VALUES
(5, 2, '2024-12-20', '2024-12-22', 1, 'Cancelled', 200.00, 220.00, 'Change of travel plans', '2024-12-15 10:00:00');
GO

-- =============================================
-- PAYMENTS DATA
-- =============================================

INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, payment_date, status, transaction_ref) VALUES
(1, 1, 513.50, 'Credit Card', '2024-10-05 10:30:00', 'Completed', 'TXN-2024-10001'),
(2, 2, 379.50, 'Debit Card', '2024-10-12 10:00:00', 'Completed', 'TXN-2024-10002'),
(3, 3, 1495.00, 'Credit Card', '2024-10-20 11:00:00', 'Completed', 'TXN-2024-10003'),
(4, 4, 1303.00, 'Bank Transfer', '2024-11-04 09:30:00', 'Completed', 'TXN-2024-11001'),
(5, 5, 110.00, 'Cash', '2024-11-11 09:45:00', 'Completed', 'TXN-2024-11002'),
(6, 6, 906.00, 'Credit Card', '2024-11-18 10:45:00', 'Completed', 'TXN-2024-11003'),
(7, 7, 440.00, 'Credit Card', '2024-12-26 14:30:00', 'Completed', 'TXN-2024-12001'),
(8, 8, 330.00, 'Debit Card', '2024-12-27 15:45:00', 'Completed', 'TXN-2024-12002'),
(9, 9, 1000.00, 'Credit Card', '2024-12-25 13:30:00', 'Partial', 'TXN-2024-12003'),
(10, 10, 1925.00, 'Bank Transfer', '2024-12-28 16:30:00', 'Completed', 'TXN-2024-12004');
GO

-- =============================================
-- SERVICES USED DATA
-- =============================================

INSERT INTO SERVICES_USED (reservation_id, service_id, quantity, unit_price, total_price, used_date, status) VALUES
-- Reservation 1 services
(1, 1, 2, 35.00, 70.00, '2024-10-02 08:00:00', 'Completed'),
(1, 11, 1, 25.00, 25.00, '2024-10-03 10:00:00', 'Completed'),

-- Reservation 2 services
(2, 6, 1, 90.00, 90.00, '2024-10-11 14:00:00', 'Completed'),

-- Reservation 3 services (high spender)
(3, 3, 3, 75.00, 225.00, '2024-10-16 19:00:00', 'Completed'),
(3, 6, 2, 90.00, 180.00, '2024-10-17 15:00:00', 'Completed'),
(3, 5, 1, 120.00, 120.00, '2024-10-18 20:00:00', 'Completed'),

-- Reservation 4 services
(4, 15, 2, 60.00, 120.00, '2024-11-01 10:00:00', 'Completed'),
(4, 17, 1, 150.00, 150.00, '2024-11-02 09:00:00', 'Completed'),

-- Reservation 6 services
(6, 1, 3, 35.00, 105.00, '2024-11-16 08:00:00', 'Completed'),
(6, 8, 1, 80.00, 80.00, '2024-11-17 11:00:00', 'Completed'),
(6, 14, 2, 15.00, 30.00, '2024-11-17 14:00:00', 'Completed'),

-- Current reservation services
(9, 1, 2, 35.00, 70.00, '2024-12-26 08:00:00', 'Completed'),
(9, 6, 1, 90.00, 90.00, '2024-12-27 14:00:00', 'Completed');
GO

-- =============================================
-- MAINTENANCE REQUESTS DATA
-- =============================================

INSERT INTO MAINTENANCE_REQUESTS (room_id, assigned_to, title, description, priority, status, estimated_cost, actual_cost, created_at, started_at, completed_at) VALUES
-- Completed requests
(5, 14, 'AC Not Working', 'Air conditioning unit making noise and not cooling properly', 'High', 'Completed', 150.00, 180.00, '2024-12-20 09:00:00', '2024-12-20 10:00:00', '2024-12-20 14:00:00'),
(28, 15, 'Bathroom Leak', 'Slow leak under bathroom sink', 'Medium', 'Completed', 80.00, 65.00, '2024-12-22 14:00:00', '2024-12-22 15:00:00', '2024-12-22 17:00:00'),
(8, 14, 'TV Remote Broken', 'Television remote control not functioning', 'Low', 'Completed', 20.00, 15.00, '2024-12-23 11:00:00', '2024-12-23 12:00:00', '2024-12-23 12:30:00'),

-- In progress
(5, 15, 'Replace Carpet', 'Carpet stained and needs replacement', 'Medium', 'InProgress', 500.00, NULL, '2024-12-27 09:00:00', '2024-12-28 08:00:00', NULL),

-- Open requests
(28, NULL, 'Window Won''t Close', 'Window mechanism stuck, won''t close properly', 'High', 'Open', 100.00, NULL, '2024-12-28 10:00:00', NULL, NULL),
(17, NULL, 'Light Bulb Out', 'Bedside lamp bulb needs replacement', 'Low', 'Open', 10.00, NULL, '2024-12-28 08:00:00', NULL, NULL);
GO

-- =============================================
-- EMPLOYEE SHIFTS DATA
-- =============================================

-- Insert shifts for current week
INSERT INTO EMPLOYEE_SHIFTS (employee_id, shift_date, start_time, end_time, status) VALUES
-- Front Desk shifts
(1, '2024-12-28', '07:00', '15:00', 'Scheduled'),
(2, '2024-12-28', '07:00', '15:00', 'Scheduled'),
(3, '2024-12-28', '15:00', '23:00', 'Scheduled'),
(4, '2024-12-28', '23:00', '07:00', 'Scheduled'),

-- Housekeeping shifts
(5, '2024-12-28', '06:00', '14:00', 'Scheduled'),
(6, '2024-12-28', '06:00', '14:00', 'Scheduled'),
(7, '2024-12-28', '14:00', '22:00', 'Scheduled'),
(8, '2024-12-28', '14:00', '22:00', 'Scheduled'),

-- F&B shifts
(9, '2024-12-28', '10:00', '18:00', 'Scheduled'),
(10, '2024-12-28', '06:00', '14:00', 'Scheduled'),
(11, '2024-12-28', '11:00', '19:00', 'Scheduled'),
(12, '2024-12-28', '16:00', '00:00', 'Scheduled'),

-- Maintenance shifts
(13, '2024-12-28', '08:00', '16:00', 'Scheduled'),
(14, '2024-12-28', '08:00', '16:00', 'Scheduled'),
(15, '2024-12-28', '16:00', '00:00', 'Scheduled'),

-- Security shifts
(16, '2024-12-28', '06:00', '18:00', 'Scheduled'),
(17, '2024-12-28', '18:00', '06:00', 'Scheduled');
GO

GO
-- =============================================
-- SAMPLE DATA FOR AUTHENTICATION TABLES
-- Password for all users: Password123
-- Hash generated with SHA2_256(salt + 'Password123')
-- =============================================

USE HotelManagement;
GO

-- Pre-computed hash for 'Password123'
-- This is for TESTING/DEMO only, real system should use proper password hashing

DECLARE @sample_hash NVARCHAR(256);

-- Compute hash: SHA256('Password123')
SET @sample_hash = CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', 'Password123'), 2);

-- Get role IDs
DECLARE @role_admin INT, @role_manager INT, @role_reception INT, @role_cashier INT, @role_guest INT;
SELECT @role_admin = role_id FROM ROLES WHERE role_name = 'Administrator';
SELECT @role_manager = role_id FROM ROLES WHERE role_name = 'General Manager';
SELECT @role_reception = role_id FROM ROLES WHERE role_name = 'Receptionist';
SELECT @role_cashier = role_id FROM ROLES WHERE role_name = 'Cashier';
SELECT @role_guest = role_id FROM ROLES WHERE role_name = 'Guest';

-- Insert sample users (if not exist)
IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'admin')
    INSERT INTO USER_ACCOUNTS (username, password_hash, email, role_id, user_type, employee_id)
    VALUES ('admin', @sample_hash, 'admin@hotel.com', @role_admin, 'Employee', 1);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'manager')
    INSERT INTO USER_ACCOUNTS (username, password_hash, email, role_id, user_type, employee_id)
    VALUES ('manager', @sample_hash, 'manager@hotel.com', @role_manager, 'Employee', 2);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'reception1')
    INSERT INTO USER_ACCOUNTS (username, password_hash, email, role_id, user_type, employee_id)
    VALUES ('reception1', @sample_hash, 'reception1@hotel.com', @role_reception, 'Employee', 3);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'cashier1')
    INSERT INTO USER_ACCOUNTS (username, password_hash, email, role_id, user_type, employee_id)
    VALUES ('cashier1', @sample_hash, 'cashier1@hotel.com', @role_cashier, 'Employee', 4);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'guest1')
    INSERT INTO USER_ACCOUNTS (username, password_hash, email, role_id, user_type, customer_id)
    VALUES ('guest1', @sample_hash, 'guest1@email.com', @role_guest, 'Customer', 1);

PRINT 'Sample auth users created (Password: Password123)';
GO

