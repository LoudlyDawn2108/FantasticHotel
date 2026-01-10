-- =============================================
-- SAMPLE DATA FOR AUTHENTICATION TABLES
-- =============================================

USE HotelManagement;
GO

DECLARE @test_salt NVARCHAR(128);
DECLARE @test_hash NVARCHAR(256);
DECLARE @role_admin INT, @role_manager INT, @role_reception INT, @role_cashier INT, @role_guest INT;

-- Get role IDs
SELECT @role_admin = role_id FROM ROLES WHERE role_name = 'Administrator';
SELECT @role_manager = role_id FROM ROLES WHERE role_name = 'General Manager';
SELECT @role_reception = role_id FROM ROLES WHERE role_name = 'Receptionist';
SELECT @role_cashier = role_id FROM ROLES WHERE role_name = 'Cashier';
SELECT @role_guest = role_id FROM ROLES WHERE role_name = 'Guest';

-- Create admin user
SET @test_salt = dbo.fn_generate_salt();
SET @test_hash = dbo.fn_hash_password('Password123', @test_salt);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'admin')
BEGIN
    INSERT INTO USER_ACCOUNTS (username, password_hash, password_salt, email, role_id, user_type, employee_id)
    VALUES ('admin', @test_hash, @test_salt, 'admin@hotel.com', @role_admin, 'Employee', 1);
    PRINT 'Admin user created.';
END

-- Create manager user
SET @test_salt = dbo.fn_generate_salt();
SET @test_hash = dbo.fn_hash_password('Password123', @test_salt);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'manager')
BEGIN
    INSERT INTO USER_ACCOUNTS (username, password_hash, password_salt, email, role_id, user_type, employee_id)
    VALUES ('manager', @test_hash, @test_salt, 'manager@hotel.com', @role_manager, 'Employee', 2);
    PRINT 'Manager user created.';
END

-- Create receptionist user
SET @test_salt = dbo.fn_generate_salt();
SET @test_hash = dbo.fn_hash_password('Password123', @test_salt);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'reception1')
BEGIN
    INSERT INTO USER_ACCOUNTS (username, password_hash, password_salt, email, role_id, user_type, employee_id)
    VALUES ('reception1', @test_hash, @test_salt, 'reception1@hotel.com', @role_reception, 'Employee', 3);
    PRINT 'Receptionist user created.';
END

-- Create cashier user
SET @test_salt = dbo.fn_generate_salt();
SET @test_hash = dbo.fn_hash_password('Password123', @test_salt);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'cashier1')
BEGIN
    INSERT INTO USER_ACCOUNTS (username, password_hash, password_salt, email, role_id, user_type, employee_id)
    VALUES ('cashier1', @test_hash, @test_salt, 'cashier1@hotel.com', @role_cashier, 'Employee', 4);
    PRINT 'Cashier user created.';
END

-- Create guest user
SET @test_salt = dbo.fn_generate_salt();
SET @test_hash = dbo.fn_hash_password('Password123', @test_salt);

IF NOT EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = 'guest1')
BEGIN
    INSERT INTO USER_ACCOUNTS (username, password_hash, password_salt, email, role_id, user_type, customer_id)
    VALUES ('guest1', @test_hash, @test_salt, 'guest1@email.com', @role_guest, 'Customer', 1);
    PRINT 'Guest user created.';
END

PRINT '';
PRINT '================================================';
PRINT 'Sample User Accounts (Password: Password123)';
PRINT '================================================';
PRINT '  admin      | Administrator    | Level 100';
PRINT '  manager    | General Manager  | Level 90';
PRINT '  reception1 | Receptionist     | Level 50';
PRINT '  cashier1   | Cashier          | Level 50';
PRINT '  guest1     | Guest            | Level 10';
GO

-- Verify
SELECT 
    ua.username, 
    r.role_name, 
    r.role_level,
    ua.user_type
FROM USER_ACCOUNTS ua
INNER JOIN ROLES r ON ua.role_id = r.role_id
ORDER BY r.role_level DESC;
GO
