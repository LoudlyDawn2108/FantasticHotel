USE HotelManagement;
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


