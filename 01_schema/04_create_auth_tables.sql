-- =============================================
-- AUTHENTICATION & AUTHORIZATION SCHEMA
-- Shared Module: Security Management
-- =============================================
-- Simplified RBAC with:
-- - Roles with access levels
-- - User accounts with single role assignment
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- TABLE: ROLES
-- Defines system roles for access control
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ROLES')
BEGIN
    CREATE TABLE ROLES (
        role_id INT IDENTITY(1,1) PRIMARY KEY,
        role_name NVARCHAR(50) NOT NULL UNIQUE,
        description NVARCHAR(500),
        role_level INT NOT NULL DEFAULT 1,  -- Higher level = more access
        is_active BIT DEFAULT 1,
        created_at DATETIME DEFAULT GETDATE()
    );
    
    PRINT 'ROLES table created successfully.';
END
GO

-- =============================================
-- TABLE: USER_ACCOUNTS
-- Stores user login credentials with single role
-- =============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'USER_ACCOUNTS')
BEGIN
    CREATE TABLE USER_ACCOUNTS (
        user_id INT IDENTITY(1,1) PRIMARY KEY,
        username NVARCHAR(50) NOT NULL UNIQUE,
        password_hash NVARCHAR(256) NOT NULL,
        password_salt NVARCHAR(128) NOT NULL,
        email NVARCHAR(100) NOT NULL UNIQUE,
        
        -- Single role assignment
        role_id INT NOT NULL,
        
        -- Link to either employee or customer
        user_type NVARCHAR(20) NOT NULL,          -- 'Employee' or 'Customer'
        employee_id INT NULL,
        customer_id INT NULL,
        
        -- Account status
        is_active BIT DEFAULT 1,
        is_locked BIT DEFAULT 0,
        failed_login_attempts INT DEFAULT 0,
        
        -- Timestamps
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE(),
        last_login DATETIME NULL,
        
        CONSTRAINT FK_UserAccounts_Role FOREIGN KEY (role_id)
            REFERENCES ROLES(role_id),
        CONSTRAINT FK_UserAccounts_Employee FOREIGN KEY (employee_id)
            REFERENCES EMPLOYEES(employee_id),
        CONSTRAINT FK_UserAccounts_Customer FOREIGN KEY (customer_id)
            REFERENCES CUSTOMERS(customer_id),
        CONSTRAINT CK_UserType CHECK (user_type IN ('Employee', 'Customer')),
        CONSTRAINT CK_UserLink CHECK (
            (user_type = 'Employee' AND employee_id IS NOT NULL AND customer_id IS NULL) OR
            (user_type = 'Customer' AND customer_id IS NOT NULL AND employee_id IS NULL)
        )
    );
    
    CREATE INDEX IX_UserAccounts_Username ON USER_ACCOUNTS(username);
    CREATE INDEX IX_UserAccounts_RoleId ON USER_ACCOUNTS(role_id);
    
    PRINT 'USER_ACCOUNTS table created successfully.';
END
GO

-- =============================================
-- INSERT DEFAULT ROLES
-- =============================================
IF NOT EXISTS (SELECT 1 FROM ROLES WHERE role_name = 'Administrator')
BEGIN
    INSERT INTO ROLES (role_name, description, role_level) VALUES
    ('Administrator', 'Full system access', 100),
    ('General Manager', 'Hotel management, all reports', 90),
    ('Front Desk Manager', 'Manages front desk operations', 70),
    ('Finance Manager', 'Manages payments and reports', 70),
    ('Maintenance Manager', 'Manages maintenance and staff', 70),
    ('Receptionist', 'Check-in/out, reservations', 50),
    ('Cashier', 'Payments and invoices', 50),
    ('Housekeeping Staff', 'Room cleaning and status', 30),
    ('Maintenance Staff', 'Maintenance tasks', 30),
    ('F&B Staff', 'Food and beverage service', 30),
    ('Guest', 'Hotel guest self-service', 10);
    
    PRINT 'Default roles inserted.';
END
GO

PRINT '================================================';
PRINT 'Authentication Schema Created';
PRINT 'Tables: ROLES, USER_ACCOUNTS';
PRINT '================================================';
GO
