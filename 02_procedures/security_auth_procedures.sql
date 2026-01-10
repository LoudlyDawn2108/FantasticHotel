-- =============================================
-- AUTHENTICATION & AUTHORIZATION PROCEDURES
-- Shared Module: Security Management
-- =============================================
-- Simplified: Each user has one role
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- FUNCTION: fn_hash_password
-- =============================================
CREATE OR ALTER FUNCTION fn_hash_password
(
    @password NVARCHAR(100),
    @salt NVARCHAR(128)
)
RETURNS NVARCHAR(256)
AS
BEGIN
    RETURN CONVERT(NVARCHAR(256), HASHBYTES('SHA2_256', @salt + @password), 2);
END;
GO

-- =============================================
-- FUNCTION: fn_generate_salt
-- =============================================
CREATE OR ALTER FUNCTION fn_generate_salt()
RETURNS NVARCHAR(128)
AS
BEGIN
    RETURN CONVERT(NVARCHAR(128), NEWID()) + CONVERT(NVARCHAR(128), NEWID());
END;
GO

-- =============================================
-- FUNCTION: fn_get_user_role_level
-- Returns the role level for a user
-- =============================================
CREATE OR ALTER FUNCTION fn_get_user_role_level
(
    @user_id INT
)
RETURNS INT
AS
BEGIN
    DECLARE @level INT;
    
    SELECT @level = r.role_level
    FROM USER_ACCOUNTS ua
    INNER JOIN ROLES r ON ua.role_id = r.role_id
    WHERE ua.user_id = @user_id AND ua.is_active = 1;
    
    RETURN ISNULL(@level, 0);
END;
GO

-- =============================================
-- FUNCTION: fn_user_has_role
-- Checks if user has a specific role
-- =============================================
CREATE OR ALTER FUNCTION fn_user_has_role
(
    @user_id INT,
    @role_name NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM USER_ACCOUNTS ua
        INNER JOIN ROLES r ON ua.role_id = r.role_id
        WHERE ua.user_id = @user_id AND r.role_name = @role_name AND ua.is_active = 1
    )
        RETURN 1;
    
    RETURN 0;
END;
GO

-- =============================================
-- FUNCTION: fn_user_can_access
-- Checks if user has minimum role level
-- =============================================
CREATE OR ALTER FUNCTION fn_user_can_access
(
    @user_id INT,
    @required_level INT
)
RETURNS BIT
AS
BEGIN
    IF dbo.fn_get_user_role_level(@user_id) >= @required_level
        RETURN 1;
    RETURN 0;
END;
GO

-- =============================================
-- PROCEDURE: sp_create_user_account
-- =============================================
CREATE OR ALTER PROCEDURE sp_create_user_account
    @username NVARCHAR(50),
    @password NVARCHAR(100),
    @email NVARCHAR(100),
    @user_type NVARCHAR(20),
    @linked_id INT,
    @role_name NVARCHAR(50),
    @user_id INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @password_salt NVARCHAR(128);
    DECLARE @password_hash NVARCHAR(256);
    DECLARE @role_id INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validate username
        IF EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE username = @username)
        BEGIN
            SET @message = 'Error: Username already exists.';
            ROLLBACK; RETURN -1;
        END
        
        -- Validate email
        IF EXISTS (SELECT 1 FROM USER_ACCOUNTS WHERE email = @email)
        BEGIN
            SET @message = 'Error: Email already exists.';
            ROLLBACK; RETURN -1;
        END
        
        -- Get role
        SELECT @role_id = role_id FROM ROLES WHERE role_name = @role_name AND is_active = 1;
        IF @role_id IS NULL
        BEGIN
            SET @message = 'Error: Role not found.';
            ROLLBACK; RETURN -1;
        END
        
        -- Validate linked entity
        IF @user_type = 'Employee'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM EMPLOYEES WHERE employee_id = @linked_id AND is_active = 1)
            BEGIN
                SET @message = 'Error: Employee not found.';
                ROLLBACK; RETURN -1;
            END
        END
        ELSE IF @user_type = 'Customer'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM CUSTOMERS WHERE customer_id = @linked_id AND is_active = 1)
            BEGIN
                SET @message = 'Error: Customer not found.';
                ROLLBACK; RETURN -1;
            END
        END
        ELSE
        BEGIN
            SET @message = 'Error: Invalid user type.';
            ROLLBACK; RETURN -1;
        END
        
        -- Validate password
        IF LEN(@password) < 8
        BEGIN
            SET @message = 'Error: Password must be at least 8 characters.';
            ROLLBACK; RETURN -1;
        END
        
        -- Hash password
        SET @password_salt = dbo.fn_generate_salt();
        SET @password_hash = dbo.fn_hash_password(@password, @password_salt);
        
        -- Create account
        INSERT INTO USER_ACCOUNTS (
            username, password_hash, password_salt, email, role_id,
            user_type, employee_id, customer_id
        )
        VALUES (
            @username, @password_hash, @password_salt, @email, @role_id,
            @user_type,
            CASE WHEN @user_type = 'Employee' THEN @linked_id ELSE NULL END,
            CASE WHEN @user_type = 'Customer' THEN @linked_id ELSE NULL END
        );
        
        SET @user_id = SCOPE_IDENTITY();
        COMMIT;
        
        SET @message = 'User created successfully.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @user_id = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- PROCEDURE: sp_user_login
-- =============================================
CREATE OR ALTER PROCEDURE sp_user_login
    @username NVARCHAR(50),
    @password NVARCHAR(100),
    @user_id INT OUTPUT,
    @role_name NVARCHAR(50) OUTPUT,
    @role_level INT OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @stored_hash NVARCHAR(256);
    DECLARE @stored_salt NVARCHAR(128);
    DECLARE @computed_hash NVARCHAR(256);
    DECLARE @is_active BIT, @is_locked BIT;
    DECLARE @failed_attempts INT, @max_attempts INT = 5;
    
    SET @user_id = NULL;
    SET @role_name = NULL;
    SET @role_level = 0;
    
    -- Get user
    SELECT 
        @user_id = ua.user_id,
        @stored_hash = ua.password_hash,
        @stored_salt = ua.password_salt,
        @is_active = ua.is_active,
        @is_locked = ua.is_locked,
        @failed_attempts = ua.failed_login_attempts,
        @role_name = r.role_name,
        @role_level = r.role_level
    FROM USER_ACCOUNTS ua
    INNER JOIN ROLES r ON ua.role_id = r.role_id
    WHERE ua.username = @username;
    
    IF @user_id IS NULL
    BEGIN
        SET @message = 'Invalid username or password.';
        RETURN -1;
    END
    
    IF @is_active = 0
    BEGIN
        SET @user_id = NULL;
        SET @message = 'Account is inactive.';
        RETURN -1;
    END
    
    IF @is_locked = 1
    BEGIN
        SET @user_id = NULL;
        SET @message = 'Account is locked.';
        RETURN -1;
    END
    
    -- Verify password
    SET @computed_hash = dbo.fn_hash_password(@password, @stored_salt);
    
    IF @computed_hash != @stored_hash
    BEGIN
        SET @failed_attempts = @failed_attempts + 1;
        
        IF @failed_attempts >= @max_attempts
        BEGIN
            UPDATE USER_ACCOUNTS SET is_locked = 1, failed_login_attempts = @failed_attempts
            WHERE user_id = @user_id;
            SET @message = 'Account locked.';
        END
        ELSE
        BEGIN
            UPDATE USER_ACCOUNTS SET failed_login_attempts = @failed_attempts
            WHERE user_id = @user_id;
            SET @message = 'Invalid username or password.';
        END
        
        SET @user_id = NULL;
        SET @role_name = NULL;
        SET @role_level = 0;
        RETURN -1;
    END
    
    -- Success
    UPDATE USER_ACCOUNTS
    SET failed_login_attempts = 0, last_login = GETDATE(), updated_at = GETDATE()
    WHERE user_id = @user_id;
    
    SET @message = 'Login successful.';
    RETURN 0;
END;
GO

-- =============================================
-- PROCEDURE: sp_change_password
-- =============================================
CREATE OR ALTER PROCEDURE sp_change_password
    @user_id INT,
    @old_password NVARCHAR(100),
    @new_password NVARCHAR(100),
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @stored_hash NVARCHAR(256), @stored_salt NVARCHAR(128);
    DECLARE @new_salt NVARCHAR(128), @new_hash NVARCHAR(256);
    
    SELECT @stored_hash = password_hash, @stored_salt = password_salt
    FROM USER_ACCOUNTS WHERE user_id = @user_id AND is_active = 1;
    
    IF @stored_hash IS NULL
    BEGIN
        SET @message = 'Error: User not found.';
        RETURN -1;
    END
    
    IF dbo.fn_hash_password(@old_password, @stored_salt) != @stored_hash
    BEGIN
        SET @message = 'Error: Current password is incorrect.';
        RETURN -1;
    END
    
    IF LEN(@new_password) < 8
    BEGIN
        SET @message = 'Error: New password must be at least 8 characters.';
        RETURN -1;
    END
    
    SET @new_salt = dbo.fn_generate_salt();
    SET @new_hash = dbo.fn_hash_password(@new_password, @new_salt);
    
    UPDATE USER_ACCOUNTS
    SET password_hash = @new_hash, password_salt = @new_salt, updated_at = GETDATE()
    WHERE user_id = @user_id;
    
    SET @message = 'Password changed successfully.';
    RETURN 0;
END;
GO

-- =============================================
-- PROCEDURE: sp_change_user_role
-- Changes a user's role (requires manager level)
-- =============================================
CREATE OR ALTER PROCEDURE sp_change_user_role
    @target_user_id INT,
    @new_role_name NVARCHAR(50),
    @admin_user_id INT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @new_role_id INT;
    
    -- Check admin access
    IF dbo.fn_get_user_role_level(@admin_user_id) < 70
    BEGIN
        SET @message = 'Error: Insufficient permissions.';
        RETURN -1;
    END
    
    -- Get new role
    SELECT @new_role_id = role_id FROM ROLES WHERE role_name = @new_role_name AND is_active = 1;
    IF @new_role_id IS NULL
    BEGIN
        SET @message = 'Error: Role not found.';
        RETURN -1;
    END
    
    -- Update role
    UPDATE USER_ACCOUNTS
    SET role_id = @new_role_id, updated_at = GETDATE()
    WHERE user_id = @target_user_id;
    
    IF @@ROWCOUNT = 0
    BEGIN
        SET @message = 'Error: User not found.';
        RETURN -1;
    END
    
    SET @message = 'Role changed to ' + @new_role_name + '.';
    RETURN 0;
END;
GO

-- =============================================
-- PROCEDURE: sp_unlock_user
-- =============================================
CREATE OR ALTER PROCEDURE sp_unlock_user
    @target_user_id INT,
    @admin_user_id INT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF dbo.fn_get_user_role_level(@admin_user_id) < 70
    BEGIN
        SET @message = 'Error: Insufficient permissions.';
        RETURN -1;
    END
    
    UPDATE USER_ACCOUNTS
    SET is_locked = 0, failed_login_attempts = 0, updated_at = GETDATE()
    WHERE user_id = @target_user_id;
    
    IF @@ROWCOUNT = 0
    BEGIN
        SET @message = 'Error: User not found.';
        RETURN -1;
    END
    
    SET @message = 'User unlocked successfully.';
    RETURN 0;
END;
GO

PRINT 'Authentication Procedures Created Successfully.';
GO
