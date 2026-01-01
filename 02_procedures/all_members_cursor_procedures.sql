-- =============================================
-- CURSOR-BASED PROCEDURES FOR ALL MEMBERS
-- These procedures use CURSORS and are interconnected
-- to form complete business processes
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- Phuc - CURSOR 1: sp_batch_confirm_reservations
-- Confirms all pending reservations for today
-- using cursor to process each one
-- CONNECTS TO: Khanh (triggers payment reminders)
-- =============================================
CREATE OR ALTER PROCEDURE sp_batch_confirm_reservations
    @confirmed_count INT OUTPUT,
    @message NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @check_in_date DATE;
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    
    SET @confirmed_count = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cursor to find all pending reservations checking in today or tomorrow
        DECLARE reservation_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                r.customer_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                r.room_id,
                rm.room_number,
                r.check_in_date,
                r.total_amount,
                r.paid_amount
            FROM RESERVATIONS r
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            WHERE r.status = 'Pending'
            AND r.check_in_date BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 1, CAST(GETDATE() AS DATE))
            ORDER BY r.check_in_date, r.reservation_id;
        
        OPEN reservation_cursor;
        FETCH NEXT FROM reservation_cursor INTO 
            @reservation_id, @customer_id, @customer_name, @room_id, 
            @room_number, @check_in_date, @total_amount, @paid_amount;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Update reservation status to Confirmed
            UPDATE RESERVATIONS
            SET status = 'Confirmed', updated_at = GETDATE()
            WHERE reservation_id = @reservation_id;
            
            -- Update room status to Reserved if check-in is today
            IF @check_in_date = CAST(GETDATE() AS DATE)
            BEGIN
                UPDATE ROOMS
                SET status = 'Reserved', updated_at = GETDATE()
                WHERE room_id = @room_id AND status = 'Available';
            END
            
            -- Create notification for guest
            INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
            VALUES ('Confirmation', 'Reservation Confirmed',
                    'Your reservation #' + CAST(@reservation_id AS NVARCHAR) + ' for Room ' + @room_number + 
                    ' on ' + FORMAT(@check_in_date, 'MMM dd, yyyy') + ' has been confirmed.',
                    'RESERVATIONS', @reservation_id, 'Customer', @customer_id);
            
            -- If not fully paid, trigger payment reminder (connects to Khanh)
            IF @paid_amount < @total_amount
            BEGIN
                INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
                VALUES ('PaymentReminder', 'Payment Required',
                        'Balance due for reservation #' + CAST(@reservation_id AS NVARCHAR) + ': $' + 
                        CAST(@total_amount - @paid_amount AS NVARCHAR) + '. Please complete payment before check-in.',
                        'RESERVATIONS', @reservation_id, 'Customer', @customer_id);
            END
            
            SET @confirmed_count = @confirmed_count + 1;
            SET @message = @message + 'Confirmed: #' + CAST(@reservation_id AS NVARCHAR) + 
                           ' - ' + @customer_name + ' (Room ' + @room_number + ')' + CHAR(13) + CHAR(10);
            
            FETCH NEXT FROM reservation_cursor INTO 
                @reservation_id, @customer_id, @customer_name, @room_id, 
                @room_number, @check_in_date, @total_amount, @paid_amount;
        END
        
        CLOSE reservation_cursor;
        DEALLOCATE reservation_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Batch confirmation completed. ' + CAST(@confirmed_count AS NVARCHAR) + 
                       ' reservations confirmed.' + CHAR(13) + CHAR(10) + @message;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'reservation_cursor') >= 0
        BEGIN
            CLOSE reservation_cursor;
            DEALLOCATE reservation_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Phuc - CURSOR 2: sp_process_daily_checkouts
-- Processes all guests that should checkout today
-- using cursor, calculates final bills
-- CONNECTS TO: Khanh (invoice), Tung (housekeeping)
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_daily_checkouts
    @checkout_count INT OUTPUT,
    @total_revenue DECIMAL(15,2) OUTPUT,
    @message NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @balance_due DECIMAL(10,2);
    
    SET @checkout_count = 0;
    SET @total_revenue = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cursor to find all checked-in guests with checkout today
        DECLARE checkout_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                r.customer_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                r.room_id,
                rm.room_number,
                r.total_amount,
                r.paid_amount
            FROM RESERVATIONS r
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            WHERE r.status = 'CheckedIn'
            AND r.check_out_date = CAST(GETDATE() AS DATE)
            ORDER BY r.room_id;
        
        OPEN checkout_cursor;
        FETCH NEXT FROM checkout_cursor INTO 
            @reservation_id, @customer_id, @customer_name, @room_id, 
            @room_number, @total_amount, @paid_amount;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @balance_due = @total_amount - @paid_amount;
            
            -- Create checkout reminder notification
            INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
            VALUES ('CheckoutReminder', 'Checkout Today',
                    'Dear ' + @customer_name + ', your checkout is today. ' +
                    CASE WHEN @balance_due > 0 
                         THEN 'Outstanding balance: $' + CAST(@balance_due AS NVARCHAR) 
                         ELSE 'Your bill is fully paid.' END,
                    'RESERVATIONS', @reservation_id, 'Customer', @customer_id);
            
            -- Create notification for front desk
            INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
            VALUES ('CheckoutDue', 'Guest Checkout Due',
                    'Room ' + @room_number + ' - ' + @customer_name + ' checkout due today. ' +
                    'Balance: $' + CAST(@balance_due AS NVARCHAR),
                    'RESERVATIONS', @reservation_id, 'Front Desk');
            
            -- If balance is 0, can auto-process checkout
            IF @balance_due = 0
            BEGIN
                UPDATE RESERVATIONS
                SET status = 'CheckedOut', 
                    actual_check_out = GETDATE(),
                    updated_at = GETDATE()
                WHERE reservation_id = @reservation_id;
                
                -- Room goes to cleaning (connects to Tung housekeeping)
                UPDATE ROOMS
                SET status = 'Cleaning', updated_at = GETDATE()
                WHERE room_id = @room_id;
                
                -- Notify housekeeping (connects to Tung)
                INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type)
                VALUES ('RoomCleaning', 'Room Ready for Cleaning',
                        'Room ' + @room_number + ' has checked out and needs cleaning.',
                        'ROOMS', @room_id, 'Housekeeping');
            END
            
            SET @checkout_count = @checkout_count + 1;
            SET @total_revenue = @total_revenue + @total_amount;
            SET @message = @message + 'Room ' + @room_number + ': ' + @customer_name + 
                           ' - $' + CAST(@total_amount AS NVARCHAR) + 
                           CASE WHEN @balance_due > 0 THEN ' (UNPAID: $' + CAST(@balance_due AS NVARCHAR) + ')' ELSE ' (PAID)' END +
                           CHAR(13) + CHAR(10);
            
            FETCH NEXT FROM checkout_cursor INTO 
                @reservation_id, @customer_id, @customer_name, @room_id, 
                @room_number, @total_amount, @paid_amount;
        END
        
        CLOSE checkout_cursor;
        DEALLOCATE checkout_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Daily checkout processing completed.' + CHAR(13) + CHAR(10) +
                       'Total checkouts: ' + CAST(@checkout_count AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       'Total revenue: $' + CAST(@total_revenue AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       '---' + CHAR(13) + CHAR(10) + @message;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'checkout_cursor') >= 0
        BEGIN
            CLOSE checkout_cursor;
            DEALLOCATE checkout_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Khanh - CURSOR 1: sp_process_batch_payments
-- Processes multiple pending payments using cursor
-- CONNECTS TO: Phuc (updates reservations), Ninh (loyalty points)
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_batch_payments
    @payment_date DATE = NULL,
    @processed_count INT OUTPUT,
    @total_processed DECIMAL(15,2) OUTPUT,
    @message NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @payment_date IS NULL
        SET @payment_date = CAST(GETDATE() AS DATE);
    
    DECLARE @payment_id INT;
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @amount DECIMAL(10,2);
    DECLARE @payment_method NVARCHAR(50);
    DECLARE @customer_tier NVARCHAR(20);
    DECLARE @points_earned INT;
    
    SET @processed_count = 0;
    SET @total_processed = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cursor to find all pending payments
        DECLARE payment_cursor CURSOR FOR
            SELECT 
                p.payment_id,
                p.reservation_id,
                p.customer_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                p.amount,
                p.payment_method,
                c.membership_tier
            FROM PAYMENTS p
            INNER JOIN CUSTOMERS c ON p.customer_id = c.customer_id
            WHERE p.status = 'Pending'
            AND CAST(p.payment_date AS DATE) = @payment_date
            ORDER BY p.payment_id;
        
        OPEN payment_cursor;
        FETCH NEXT FROM payment_cursor INTO 
            @payment_id, @reservation_id, @customer_id, @customer_name,
            @amount, @payment_method, @customer_tier;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Update payment status to Completed
            UPDATE PAYMENTS
            SET status = 'Completed'
            WHERE payment_id = @payment_id;
            
            -- Update reservation paid amount (connects to Phuc)
            UPDATE RESERVATIONS
            SET paid_amount = paid_amount + @amount,
                updated_at = GETDATE()
            WHERE reservation_id = @reservation_id;
            
            -- Calculate and award loyalty points (connects to Ninh)
            SET @points_earned = dbo.fn_calculate_loyalty_points(@amount, @customer_tier);
            
            UPDATE CUSTOMERS
            SET loyalty_points = loyalty_points + @points_earned,
                total_spending = total_spending + @amount,
                updated_at = GETDATE()
            WHERE customer_id = @customer_id;
            
            -- Create payment confirmation notification
            INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
            VALUES ('PaymentConfirmed', 'Payment Received',
                    'Payment of $' + CAST(@amount AS NVARCHAR) + ' received via ' + @payment_method + 
                    '. You earned ' + CAST(@points_earned AS NVARCHAR) + ' loyalty points!',
                    'PAYMENTS', @payment_id, 'Customer', @customer_id);
            
            SET @processed_count = @processed_count + 1;
            SET @total_processed = @total_processed + @amount;
            SET @message = @message + 'Payment #' + CAST(@payment_id AS NVARCHAR) + ': ' + 
                           @customer_name + ' - $' + CAST(@amount AS NVARCHAR) + 
                           ' (+' + CAST(@points_earned AS NVARCHAR) + ' pts)' + CHAR(13) + CHAR(10);
            
            FETCH NEXT FROM payment_cursor INTO 
                @payment_id, @reservation_id, @customer_id, @customer_name,
                @amount, @payment_method, @customer_tier;
        END
        
        CLOSE payment_cursor;
        DEALLOCATE payment_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Batch payment processing completed.' + CHAR(13) + CHAR(10) +
                       'Total payments: ' + CAST(@processed_count AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       'Total amount: $' + CAST(@total_processed AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       '---' + CHAR(13) + CHAR(10) + @message;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'payment_cursor') >= 0
        BEGIN
            CLOSE payment_cursor;
            DEALLOCATE payment_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Khanh - CURSOR 2: sp_generate_daily_revenue_summary
-- Generates revenue summary by iterating through payments
-- CONNECTS TO: Phuc (reservations), Ninh (services)
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_daily_revenue_summary
    @report_date DATE = NULL,
    @report_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @report_date IS NULL
        SET @report_date = CAST(GETDATE() AS DATE);
    
    DECLARE @room_type NVARCHAR(50);
    DECLARE @type_revenue DECIMAL(15,2);
    DECLARE @type_count INT;
    DECLARE @total_revenue DECIMAL(15,2) = 0;
    DECLARE @total_count INT = 0;
    DECLARE @room_summary NVARCHAR(MAX) = '';
    
    DECLARE @service_category NVARCHAR(100);
    DECLARE @service_revenue DECIMAL(15,2);
    DECLARE @service_count INT;
    DECLARE @service_summary NVARCHAR(MAX) = '';
    DECLARE @total_service_revenue DECIMAL(15,2) = 0;
    
    BEGIN TRY
        -- Cursor 1: Revenue by room type (connects to Phuc)
        DECLARE room_revenue_cursor CURSOR FOR
            SELECT 
                rt.type_name,
                SUM(p.amount) AS revenue,
                COUNT(*) AS payment_count
            FROM PAYMENTS p
            INNER JOIN RESERVATIONS r ON p.reservation_id = r.reservation_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
            WHERE CAST(p.payment_date AS DATE) = @report_date
            AND p.status = 'Completed'
            AND p.amount > 0
            GROUP BY rt.type_name
            ORDER BY SUM(p.amount) DESC;
        
        OPEN room_revenue_cursor;
        FETCH NEXT FROM room_revenue_cursor INTO @room_type, @type_revenue, @type_count;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @room_summary = @room_summary + '  ' + @room_type + ': $' + 
                               FORMAT(@type_revenue, 'N2') + ' (' + CAST(@type_count AS NVARCHAR) + ' payments)' + 
                               CHAR(13) + CHAR(10);
            SET @total_revenue = @total_revenue + @type_revenue;
            SET @total_count = @total_count + @type_count;
            
            FETCH NEXT FROM room_revenue_cursor INTO @room_type, @type_revenue, @type_count;
        END
        
        CLOSE room_revenue_cursor;
        DEALLOCATE room_revenue_cursor;
        
        -- Cursor 2: Revenue by service category (connects to Ninh)
        DECLARE service_revenue_cursor CURSOR FOR
            SELECT 
                sc.category_name,
                SUM(su.total_price) AS revenue,
                SUM(su.quantity) AS usage_count
            FROM SERVICES_USED su
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
            WHERE CAST(su.used_date AS DATE) = @report_date
            AND su.status = 'Completed'
            GROUP BY sc.category_name
            ORDER BY SUM(su.total_price) DESC;
        
        OPEN service_revenue_cursor;
        FETCH NEXT FROM service_revenue_cursor INTO @service_category, @service_revenue, @service_count;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @service_summary = @service_summary + '  ' + @service_category + ': $' + 
                                  FORMAT(@service_revenue, 'N2') + ' (' + CAST(@service_count AS NVARCHAR) + ' uses)' + 
                                  CHAR(13) + CHAR(10);
            SET @total_service_revenue = @total_service_revenue + @service_revenue;
            
            FETCH NEXT FROM service_revenue_cursor INTO @service_category, @service_revenue, @service_count;
        END
        
        CLOSE service_revenue_cursor;
        DEALLOCATE service_revenue_cursor;
        
        -- Build report output
        SET @report_output = 
'╔══════════════════════════════════════════════════════════════╗
║               DAILY REVENUE SUMMARY REPORT                    ║
╠══════════════════════════════════════════════════════════════╣
  Report Date: ' + FORMAT(@report_date, 'MMMM dd, yyyy') + '
  Generated: ' + FORMAT(GETDATE(), 'MMMM dd, yyyy HH:mm') + '
  
  ROOM REVENUE BY TYPE
  ─────────────────────────────────────────────────────────────
' + CASE WHEN LEN(@room_summary) > 0 THEN @room_summary ELSE '  (No room payments today)' + CHAR(13) + CHAR(10) END + '
  Subtotal: $' + FORMAT(@total_revenue, 'N2') + ' (' + CAST(@total_count AS NVARCHAR) + ' payments)
  
  SERVICE REVENUE BY CATEGORY
  ─────────────────────────────────────────────────────────────
' + CASE WHEN LEN(@service_summary) > 0 THEN @service_summary ELSE '  (No services used today)' + CHAR(13) + CHAR(10) END + '
  Subtotal: $' + FORMAT(@total_service_revenue, 'N2') + '
  
  ═════════════════════════════════════════════════════════════
  GRAND TOTAL: $' + FORMAT(@total_revenue + @total_service_revenue, 'N2') + '
╚══════════════════════════════════════════════════════════════╝';
        
        SET @message = 'Revenue summary generated for ' + FORMAT(@report_date, 'MMM dd, yyyy');
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'room_revenue_cursor') >= 0
        BEGIN
            CLOSE room_revenue_cursor;
            DEALLOCATE room_revenue_cursor;
        END
        IF CURSOR_STATUS('local', 'service_revenue_cursor') >= 0
        BEGIN
            CLOSE service_revenue_cursor;
            DEALLOCATE service_revenue_cursor;
        END
        
        SET @report_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Ninh - CURSOR 1: sp_process_loyalty_tier_upgrades
-- Checks all customers for tier upgrades using cursor
-- CONNECTS TO: Khanh (based on spending)
-- =============================================
CREATE OR ALTER PROCEDURE sp_process_loyalty_tier_upgrades
    @upgraded_count INT OUTPUT,
    @message NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @current_tier NVARCHAR(20);
    DECLARE @total_spending DECIMAL(15,2);
    DECLARE @new_tier NVARCHAR(20);
    DECLARE @upgrade_list NVARCHAR(MAX) = '';
    
    SET @upgraded_count = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cursor to check all customers for tier upgrades
        DECLARE tier_cursor CURSOR FOR
            SELECT 
                customer_id,
                first_name + ' ' + last_name AS customer_name,
                membership_tier,
                total_spending
            FROM CUSTOMERS
            WHERE is_active = 1
            ORDER BY total_spending DESC;
        
        OPEN tier_cursor;
        FETCH NEXT FROM tier_cursor INTO @customer_id, @customer_name, @current_tier, @total_spending;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Calculate new tier based on spending
            SET @new_tier = dbo.fn_get_customer_tier(@total_spending);
            
            -- Check if upgrade is needed (only upgrade, never downgrade)
            IF (@new_tier = 'Platinum' AND @current_tier IN ('Bronze', 'Silver', 'Gold')) OR
               (@new_tier = 'Gold' AND @current_tier IN ('Bronze', 'Silver')) OR
               (@new_tier = 'Silver' AND @current_tier = 'Bronze')
            BEGIN
                -- Upgrade customer
                UPDATE CUSTOMERS
                SET membership_tier = @new_tier, updated_at = GETDATE()
                WHERE customer_id = @customer_id;
                
                -- Award bonus points for upgrade
                DECLARE @bonus_points INT = CASE @new_tier
                    WHEN 'Silver' THEN 500
                    WHEN 'Gold' THEN 1000
                    WHEN 'Platinum' THEN 2000
                    ELSE 0
                END;
                
                UPDATE CUSTOMERS
                SET loyalty_points = loyalty_points + @bonus_points
                WHERE customer_id = @customer_id;
                
                -- Create upgrade notification
                INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
                VALUES ('TierUpgrade', 'Congratulations! Membership Upgraded',
                        'Dear ' + @customer_name + ', you have been upgraded from ' + @current_tier + ' to ' + @new_tier + ' tier! ' +
                        'Bonus: ' + CAST(@bonus_points AS NVARCHAR) + ' points added. New benefits: ' +
                        CASE @new_tier
                            WHEN 'Silver' THEN '5% discount, priority check-in'
                            WHEN 'Gold' THEN '10% discount, free upgrades, late checkout'
                            WHEN 'Platinum' THEN '15% discount, VIP lounge, free breakfast'
                            ELSE ''
                        END,
                        'CUSTOMERS', @customer_id, 'Customer', @customer_id);
                
                SET @upgraded_count = @upgraded_count + 1;
                SET @upgrade_list = @upgrade_list + @customer_name + ': ' + @current_tier + ' → ' + @new_tier + 
                                   ' (+' + CAST(@bonus_points AS NVARCHAR) + ' pts)' + CHAR(13) + CHAR(10);
            END
            
            FETCH NEXT FROM tier_cursor INTO @customer_id, @customer_name, @current_tier, @total_spending;
        END
        
        CLOSE tier_cursor;
        DEALLOCATE tier_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Loyalty tier upgrade processing completed.' + CHAR(13) + CHAR(10) +
                       'Total upgrades: ' + CAST(@upgraded_count AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       CASE WHEN @upgraded_count > 0 THEN '---' + CHAR(13) + CHAR(10) + @upgrade_list ELSE '' END;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'tier_cursor') >= 0
        BEGIN
            CLOSE tier_cursor;
            DEALLOCATE tier_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Ninh - CURSOR 2: sp_generate_service_usage_report
-- Generates detailed service usage report per reservation
-- CONNECTS TO: Phuc (reservations), Khanh (billing)
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_service_usage_report
    @start_date DATE,
    @end_date DATE,
    @report_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @room_number NVARCHAR(10);
    DECLARE @service_name NVARCHAR(100);
    DECLARE @quantity INT;
    DECLARE @total_price DECIMAL(10,2);
    DECLARE @service_date DATETIME;
    
    DECLARE @current_reservation INT = 0;
    DECLARE @reservation_total DECIMAL(10,2) = 0;
    DECLARE @grand_total DECIMAL(15,2) = 0;
    DECLARE @service_count INT = 0;
    DECLARE @report_body NVARCHAR(MAX) = '';
    
    BEGIN TRY
        -- Cursor to iterate through all service usage
        DECLARE service_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                rm.room_number,
                s.service_name,
                su.quantity,
                su.total_price,
                su.used_date
            FROM SERVICES_USED su
            INNER JOIN RESERVATIONS r ON su.reservation_id = r.reservation_id
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            WHERE CAST(su.used_date AS DATE) BETWEEN @start_date AND @end_date
            AND su.status = 'Completed'
            ORDER BY r.reservation_id, su.used_date;
        
        OPEN service_cursor;
        FETCH NEXT FROM service_cursor INTO 
            @reservation_id, @customer_name, @room_number, @service_name, 
            @quantity, @total_price, @service_date;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Check if new reservation
            IF @reservation_id <> @current_reservation
            BEGIN
                -- Close previous reservation if exists
                IF @current_reservation > 0
                BEGIN
                    SET @report_body = @report_body + '    ────────────────────────────────────' + CHAR(13) + CHAR(10);
                    SET @report_body = @report_body + '    Subtotal: $' + FORMAT(@reservation_total, 'N2') + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);
                END
                
                -- Start new reservation section
                SET @current_reservation = @reservation_id;
                SET @reservation_total = 0;
                SET @report_body = @report_body + '  Reservation #' + CAST(@reservation_id AS NVARCHAR) + 
                                  ' | Room ' + @room_number + ' | ' + @customer_name + CHAR(13) + CHAR(10);
            END
            
            -- Add service line
            SET @report_body = @report_body + '    • ' + @service_name + ' x' + CAST(@quantity AS NVARCHAR) + 
                              ' = $' + FORMAT(@total_price, 'N2') + 
                              ' (' + FORMAT(@service_date, 'MMM dd HH:mm') + ')' + CHAR(13) + CHAR(10);
            
            SET @reservation_total = @reservation_total + @total_price;
            SET @grand_total = @grand_total + @total_price;
            SET @service_count = @service_count + 1;
            
            FETCH NEXT FROM service_cursor INTO 
                @reservation_id, @customer_name, @room_number, @service_name, 
                @quantity, @total_price, @service_date;
        END
        
        -- Close last reservation
        IF @current_reservation > 0
        BEGIN
            SET @report_body = @report_body + '    ────────────────────────────────────' + CHAR(13) + CHAR(10);
            SET @report_body = @report_body + '    Subtotal: $' + FORMAT(@reservation_total, 'N2') + CHAR(13) + CHAR(10);
        END
        
        CLOSE service_cursor;
        DEALLOCATE service_cursor;
        
        -- Build report output
        SET @report_output = 
'╔══════════════════════════════════════════════════════════════╗
║                 SERVICE USAGE REPORT                          ║
╠══════════════════════════════════════════════════════════════╣
  Period: ' + FORMAT(@start_date, 'MMM dd') + ' - ' + FORMAT(@end_date, 'MMM dd, yyyy') + '
  Generated: ' + FORMAT(GETDATE(), 'MMMM dd, yyyy HH:mm') + '
  
  SERVICE DETAILS BY RESERVATION
  ─────────────────────────────────────────────────────────────
' + CASE WHEN @service_count > 0 THEN @report_body ELSE '  (No services used in this period)' + CHAR(13) + CHAR(10) END + '
  ═════════════════════════════════════════════════════════════
  TOTAL SERVICES: ' + CAST(@service_count AS NVARCHAR) + '
  GRAND TOTAL: $' + FORMAT(@grand_total, 'N2') + '
╚══════════════════════════════════════════════════════════════╝';
        
        SET @message = 'Service usage report generated. ' + CAST(@service_count AS NVARCHAR) + ' services, $' + FORMAT(@grand_total, 'N2') + ' total.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'service_cursor') >= 0
        BEGIN
            CLOSE service_cursor;
            DEALLOCATE service_cursor;
        END
        
        SET @report_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Tung - CURSOR 1: sp_assign_housekeeping_tasks
-- Assigns cleaning tasks to available staff using cursor
-- CONNECTS TO: Phuc (room status from checkouts)
-- =============================================
CREATE OR ALTER PROCEDURE sp_assign_housekeeping_tasks
    @assigned_count INT OUTPUT,
    @message NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @room_id INT;
    DECLARE @room_number NVARCHAR(10);
    DECLARE @floor INT;
    DECLARE @employee_id INT;
    DECLARE @employee_name NVARCHAR(100);
    DECLARE @assignment_list NVARCHAR(MAX) = '';
    
    SET @assigned_count = 0;
    SET @message = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Cursor to find all rooms needing cleaning
        DECLARE room_cursor CURSOR FOR
            SELECT 
                r.room_id,
                r.room_number,
                r.floor
            FROM ROOMS r
            WHERE r.status = 'Cleaning'
            AND r.is_active = 1
            ORDER BY r.floor, r.room_number;
        
        -- Cursor to find available housekeeping staff
        DECLARE staff_cursor CURSOR FOR
            SELECT 
                e.employee_id,
                e.first_name + ' ' + e.last_name AS employee_name
            FROM EMPLOYEES e
            INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
            WHERE d.department_name = 'Housekeeping'
            AND e.is_active = 1
            AND e.is_available = 1
            AND e.position IN ('Room Attendant', 'Housekeeping Supervisor')
            ORDER BY (
                SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                WHERE mr.assigned_to = e.employee_id 
                AND mr.status IN ('Open', 'InProgress')
            ) ASC;
        
        OPEN room_cursor;
        OPEN staff_cursor;
        
        FETCH NEXT FROM room_cursor INTO @room_id, @room_number, @floor;
        FETCH NEXT FROM staff_cursor INTO @employee_id, @employee_name;
        
        WHILE @@FETCH_STATUS = 0 AND @employee_id IS NOT NULL
        BEGIN
            -- Create a cleaning task as maintenance request
            INSERT INTO MAINTENANCE_REQUESTS (room_id, assigned_to, title, description, priority, status, created_at)
            VALUES (@room_id, @employee_id, 
                    'Room Cleaning - ' + @room_number,
                    'Standard room cleaning after guest checkout. Floor ' + CAST(@floor AS NVARCHAR),
                    'Medium', 'Open', GETDATE());
            
            -- Notify assigned staff
            INSERT INTO NOTIFICATIONS (notification_type, title, message, related_table, related_id, recipient_type, recipient_id)
            VALUES ('CleaningAssigned', 'Cleaning Task Assigned',
                    'Please clean Room ' + @room_number + ' (Floor ' + CAST(@floor AS NVARCHAR) + ')',
                    'ROOMS', @room_id, 'Employee', @employee_id);
            
            SET @assigned_count = @assigned_count + 1;
            SET @assignment_list = @assignment_list + 'Room ' + @room_number + ' → ' + @employee_name + CHAR(13) + CHAR(10);
            
            -- Get next room and cycle to next staff
            FETCH NEXT FROM room_cursor INTO @room_id, @room_number, @floor;
            FETCH NEXT FROM staff_cursor INTO @employee_id, @employee_name;
            
            -- If staff cursor exhausted, reset it
            IF @@FETCH_STATUS <> 0 AND @assigned_count > 0
            BEGIN
                CLOSE staff_cursor;
                OPEN staff_cursor;
                FETCH NEXT FROM staff_cursor INTO @employee_id, @employee_name;
            END
        END
        
        CLOSE room_cursor;
        CLOSE staff_cursor;
        DEALLOCATE room_cursor;
        DEALLOCATE staff_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Housekeeping task assignment completed.' + CHAR(13) + CHAR(10) +
                       'Total tasks assigned: ' + CAST(@assigned_count AS NVARCHAR) + CHAR(13) + CHAR(10) +
                       CASE WHEN @assigned_count > 0 THEN '---' + CHAR(13) + CHAR(10) + @assignment_list ELSE '' END;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'room_cursor') >= 0
        BEGIN
            CLOSE room_cursor;
            DEALLOCATE room_cursor;
        END
        IF CURSOR_STATUS('local', 'staff_cursor') >= 0
        BEGIN
            CLOSE staff_cursor;
            DEALLOCATE staff_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- Tung - CURSOR 2: sp_generate_staff_performance_report
-- Generates staff performance report using cursor
-- CONNECTS TO: All members (comprehensive report)
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_staff_performance_report
    @department_name NVARCHAR(100) = NULL,
    @report_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @employee_id INT;
    DECLARE @employee_name NVARCHAR(100);
    DECLARE @position NVARCHAR(100);
    DECLARE @dept_name NVARCHAR(100);
    DECLARE @tasks_completed INT;
    DECLARE @avg_completion_hours DECIMAL(10,2);
    DECLARE @shifts_worked INT;
    DECLARE @attendance_rate DECIMAL(5,2);
    
    DECLARE @report_body NVARCHAR(MAX) = '';
    DECLARE @employee_count INT = 0;
    DECLARE @total_tasks INT = 0;
    
    BEGIN TRY
        -- Cursor to iterate through employees
        DECLARE employee_cursor CURSOR FOR
            SELECT 
                e.employee_id,
                e.first_name + ' ' + e.last_name AS employee_name,
                e.position,
                d.department_name,
                
                -- Tasks completed (last 30 days)
                (SELECT COUNT(*) FROM MAINTENANCE_REQUESTS mr 
                 WHERE mr.assigned_to = e.employee_id 
                 AND mr.status = 'Completed'
                 AND mr.completed_at >= DATEADD(DAY, -30, GETDATE())) AS tasks_completed,
                
                -- Average completion time
                (SELECT AVG(DATEDIFF(MINUTE, mr.created_at, mr.completed_at) / 60.0)
                 FROM MAINTENANCE_REQUESTS mr 
                 WHERE mr.assigned_to = e.employee_id 
                 AND mr.status = 'Completed'
                 AND mr.completed_at IS NOT NULL) AS avg_completion_hours,
                
                -- Shifts worked (last 30 days)
                (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
                 WHERE es.employee_id = e.employee_id 
                 AND es.status = 'Completed'
                 AND es.shift_date >= DATEADD(DAY, -30, GETDATE())) AS shifts_worked,
                
                -- Attendance rate
                CASE 
                    WHEN (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es 
                          WHERE es.employee_id = e.employee_id 
                          AND es.shift_date >= DATEADD(DAY, -30, GETDATE())) > 0
                    THEN (SELECT COUNT(*) * 100.0 / 
                          (SELECT COUNT(*) FROM EMPLOYEE_SHIFTS es2 
                           WHERE es2.employee_id = e.employee_id 
                           AND es2.shift_date >= DATEADD(DAY, -30, GETDATE()))
                          FROM EMPLOYEE_SHIFTS es 
                          WHERE es.employee_id = e.employee_id 
                          AND es.status = 'Completed'
                          AND es.shift_date >= DATEADD(DAY, -30, GETDATE()))
                    ELSE 100
                END AS attendance_rate
                
            FROM EMPLOYEES e
            INNER JOIN DEPARTMENTS d ON e.department_id = d.department_id
            WHERE e.is_active = 1
            AND (@department_name IS NULL OR d.department_name = @department_name)
            ORDER BY d.department_name, e.first_name;
        
        OPEN employee_cursor;
        FETCH NEXT FROM employee_cursor INTO 
            @employee_id, @employee_name, @position, @dept_name,
            @tasks_completed, @avg_completion_hours, @shifts_worked, @attendance_rate;
        
        DECLARE @current_dept NVARCHAR(100) = '';
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Check if new department
            IF @dept_name <> @current_dept
            BEGIN
                SET @current_dept = @dept_name;
                SET @report_body = @report_body + CHAR(13) + CHAR(10) + '  [' + @dept_name + ']' + CHAR(13) + CHAR(10);
                SET @report_body = @report_body + '  ─────────────────────────────────────────────────────────' + CHAR(13) + CHAR(10);
            END
            
            -- Add employee line
            SET @report_body = @report_body + '  ' + @employee_name + ' (' + @position + ')' + CHAR(13) + CHAR(10);
            SET @report_body = @report_body + '    Tasks: ' + CAST(ISNULL(@tasks_completed, 0) AS NVARCHAR) + 
                              ' | Avg Time: ' + ISNULL(FORMAT(@avg_completion_hours, 'N1') + 'h', 'N/A') +
                              ' | Shifts: ' + CAST(ISNULL(@shifts_worked, 0) AS NVARCHAR) +
                              ' | Attendance: ' + FORMAT(ISNULL(@attendance_rate, 100), 'N0') + '%' + CHAR(13) + CHAR(10);
            
            SET @employee_count = @employee_count + 1;
            SET @total_tasks = @total_tasks + ISNULL(@tasks_completed, 0);
            
            FETCH NEXT FROM employee_cursor INTO 
                @employee_id, @employee_name, @position, @dept_name,
                @tasks_completed, @avg_completion_hours, @shifts_worked, @attendance_rate;
        END
        
        CLOSE employee_cursor;
        DEALLOCATE employee_cursor;
        
        -- Build report output
        SET @report_output = 
'╔══════════════════════════════════════════════════════════════╗
║              STAFF PERFORMANCE REPORT                         ║
╠══════════════════════════════════════════════════════════════╣
  Report Period: Last 30 Days
  Generated: ' + FORMAT(GETDATE(), 'MMMM dd, yyyy HH:mm') + '
  Department: ' + ISNULL(@department_name, 'All Departments') + '
  
  EMPLOYEE PERFORMANCE SUMMARY
  ─────────────────────────────────────────────────────────────
' + @report_body + '
  ═════════════════════════════════════════════════════════════
  TOTAL EMPLOYEES: ' + CAST(@employee_count AS NVARCHAR) + '
  TOTAL TASKS COMPLETED: ' + CAST(@total_tasks AS NVARCHAR) + '
╚══════════════════════════════════════════════════════════════╝';
        
        SET @message = 'Performance report generated for ' + CAST(@employee_count AS NVARCHAR) + ' employees.';
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'employee_cursor') >= 0
        BEGIN
            CLOSE employee_cursor;
            DEALLOCATE employee_cursor;
        END
        
        SET @report_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'All cursor-based procedures created successfully.';
PRINT 'Phuc: sp_batch_confirm_reservations, sp_process_daily_checkouts';
PRINT 'Khanh: sp_process_batch_payments, sp_generate_daily_revenue_summary';
PRINT 'Ninh: sp_process_loyalty_tier_upgrades, sp_generate_service_usage_report';
PRINT 'Tung: sp_assign_housekeeping_tasks, sp_generate_staff_performance_report';
GO
