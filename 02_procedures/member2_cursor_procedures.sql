-- =============================================
-- Khanh: PAYMENT & FINANCIAL MANAGEMENT
-- CURSOR PROCEDURES (2 CURSORS)
-- =============================================
-- Business Process: Complete Payment & Financial Lifecycle
-- These cursors work with sp_process_payment, sp_generate_invoice,
-- vw_daily_revenue_report, vw_outstanding_payments, trg_payment_loyalty_update,
-- trg_payment_audit, fn_calculate_total_bill, fn_calculate_loyalty_points
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- CURSOR 1: sp_send_payment_reminders
-- Sends payment reminders for reservations with outstanding balances
-- Uses CURSOR to iterate through unpaid reservations
-- =============================================
CREATE OR ALTER PROCEDURE sp_send_payment_reminders
    @days_overdue INT = 0,  -- 0 = due today, negative = past due
    @reminder_count INT OUTPUT,
    @total_outstanding DECIMAL(12,2) OUTPUT,
    @message NVARCHAR(1000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @reservation_id INT;
    DECLARE @customer_id INT;
    DECLARE @customer_name NVARCHAR(100);
    DECLARE @customer_email NVARCHAR(100);
    DECLARE @room_number NVARCHAR(10);
    DECLARE @check_out_date DATE;
    DECLARE @total_amount DECIMAL(10,2);
    DECLARE @paid_amount DECIMAL(10,2);
    DECLARE @outstanding_balance DECIMAL(10,2);
    DECLARE @days_since_checkout INT;
    DECLARE @urgency NVARCHAR(20);
    
    SET @reminder_count = 0;
    SET @total_outstanding = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- CURSOR: Iterate through reservations with outstanding payments
        DECLARE reminder_cursor CURSOR FOR
            SELECT 
                r.reservation_id,
                r.customer_id,
                c.first_name + ' ' + c.last_name AS customer_name,
                c.email AS customer_email,
                rm.room_number,
                r.check_out_date,
                r.total_amount,
                r.paid_amount,
                (r.total_amount - r.paid_amount) AS outstanding_balance,
                DATEDIFF(DAY, r.check_out_date, GETDATE()) AS days_since_checkout
            FROM RESERVATIONS r
            INNER JOIN CUSTOMERS c ON r.customer_id = c.customer_id
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            WHERE r.total_amount > r.paid_amount  -- Has outstanding balance
            AND r.status NOT IN ('Cancelled', 'Pending')  -- Valid reservation
            AND (
                (@days_overdue >= 0 AND r.check_out_date <= DATEADD(DAY, -@days_overdue, GETDATE()))
                OR
                (@days_overdue < 0 AND r.check_out_date <= GETDATE())
            )
            ORDER BY (r.total_amount - r.paid_amount) DESC;  -- Highest balance first
        
        OPEN reminder_cursor;
        FETCH NEXT FROM reminder_cursor INTO 
            @reservation_id, @customer_id, @customer_name, @customer_email,
            @room_number, @check_out_date, @total_amount, @paid_amount,
            @outstanding_balance, @days_since_checkout;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Determine urgency level
            SET @urgency = CASE 
                WHEN @days_since_checkout > 30 THEN 'Critical'
                WHEN @days_since_checkout > 14 THEN 'High'
                WHEN @days_since_checkout > 7 THEN 'Medium'
                ELSE 'Low'
            END;
            
            -- Create reminder notification for customer
            INSERT INTO NOTIFICATIONS (
                notification_type, title, message,
                related_table, related_id, recipient_type, recipient_id
            )
            VALUES (
                'PaymentReminder',
                'Payment Reminder - $' + CAST(@outstanding_balance AS NVARCHAR) + ' Due',
                'Dear ' + @customer_name + ', your reservation #' + CAST(@reservation_id AS NVARCHAR) +
                ' from ' + FORMAT(@check_out_date, 'MMM dd, yyyy') + ' has an outstanding balance of $' + 
                CAST(@outstanding_balance AS NVARCHAR) + '. Please settle at your earliest convenience.',
                'RESERVATIONS',
                @reservation_id,
                'Customer',
                @customer_id
            );
            
            -- Create notification for finance team if high urgency
            IF @urgency IN ('High', 'Critical')
            BEGIN
                INSERT INTO NOTIFICATIONS (
                    notification_type, title, message,
                    related_table, related_id, recipient_type
                )
                VALUES (
                    'OverduePayment',
                    @urgency + ' - Overdue Payment: $' + CAST(@outstanding_balance AS NVARCHAR),
                    'Reservation #' + CAST(@reservation_id AS NVARCHAR) + ' | Guest: ' + @customer_name +
                    ' | Days Overdue: ' + CAST(@days_since_checkout AS NVARCHAR) +
                    ' | Balance: $' + CAST(@outstanding_balance AS NVARCHAR),
                    'RESERVATIONS',
                    @reservation_id,
                    'Finance'
                );
            END
            
            SET @reminder_count = @reminder_count + 1;
            SET @total_outstanding = @total_outstanding + @outstanding_balance;
            
            FETCH NEXT FROM reminder_cursor INTO 
                @reservation_id, @customer_id, @customer_name, @customer_email,
                @room_number, @check_out_date, @total_amount, @paid_amount,
                @outstanding_balance, @days_since_checkout;
        END
        
        CLOSE reminder_cursor;
        DEALLOCATE reminder_cursor;
        
        COMMIT TRANSACTION;
        
        SET @message = 'Payment reminders sent successfully. ' + 
                       CAST(@reminder_count AS NVARCHAR) + ' reminders sent. ' +
                       'Total outstanding: $' + CAST(@total_outstanding AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        IF CURSOR_STATUS('local', 'reminder_cursor') >= 0
        BEGIN
            CLOSE reminder_cursor;
            DEALLOCATE reminder_cursor;
        END
        
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

-- =============================================
-- CURSOR 2: sp_generate_monthly_revenue_summary
-- Generates monthly revenue summary report using cursor
-- Calculates revenue by room type, service category, payment method
-- =============================================
CREATE OR ALTER PROCEDURE sp_generate_monthly_revenue_summary
    @year INT,
    @month INT,
    @summary_output NVARCHAR(MAX) OUTPUT,
    @message NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @start_date DATE;
    DECLARE @end_date DATE;
    DECLARE @room_type NVARCHAR(50);
    DECLARE @room_revenue DECIMAL(12,2);
    DECLARE @room_bookings INT;
    DECLARE @service_category NVARCHAR(100);
    DECLARE @service_revenue DECIMAL(12,2);
    DECLARE @payment_method NVARCHAR(50);
    DECLARE @payment_total DECIMAL(12,2);
    DECLARE @payment_count INT;
    
    DECLARE @total_room_revenue DECIMAL(12,2) = 0;
    DECLARE @total_service_revenue DECIMAL(12,2) = 0;
    DECLARE @total_payments DECIMAL(12,2) = 0;
    DECLARE @room_breakdown NVARCHAR(MAX) = '';
    DECLARE @service_breakdown NVARCHAR(MAX) = '';
    DECLARE @payment_breakdown NVARCHAR(MAX) = '';
    
    SET @start_date = DATEFROMPARTS(@year, @month, 1);
    SET @end_date = EOMONTH(@start_date);
    
    BEGIN TRY
        -- CURSOR 1: Revenue by Room Type
        DECLARE room_revenue_cursor CURSOR FOR
            SELECT 
                rt.type_name,
                SUM(r.room_charge) AS revenue,
                COUNT(*) AS bookings
            FROM RESERVATIONS r
            INNER JOIN ROOMS rm ON r.room_id = rm.room_id
            INNER JOIN ROOM_TYPES rt ON rm.type_id = rt.type_id
            WHERE r.status IN ('CheckedOut', 'CheckedIn')
            AND r.check_in_date BETWEEN @start_date AND @end_date
            GROUP BY rt.type_name
            ORDER BY SUM(r.room_charge) DESC;
        
        OPEN room_revenue_cursor;
        FETCH NEXT FROM room_revenue_cursor INTO @room_type, @room_revenue, @room_bookings;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @room_breakdown = @room_breakdown + CHAR(13) + CHAR(10) + '    ' +
                @room_type + ': $' + FORMAT(@room_revenue, 'N2') + ' (' + CAST(@room_bookings AS NVARCHAR) + ' bookings)';
            SET @total_room_revenue = @total_room_revenue + @room_revenue;
            
            FETCH NEXT FROM room_revenue_cursor INTO @room_type, @room_revenue, @room_bookings;
        END
        
        CLOSE room_revenue_cursor;
        DEALLOCATE room_revenue_cursor;
        
        -- CURSOR 2: Revenue by Service Category
        DECLARE service_revenue_cursor CURSOR FOR
            SELECT 
                sc.category_name,
                SUM(su.total_price) AS revenue
            FROM SERVICES_USED su
            INNER JOIN SERVICES s ON su.service_id = s.service_id
            INNER JOIN SERVICE_CATEGORIES sc ON s.category_id = sc.category_id
            WHERE su.status = 'Completed'
            AND CAST(su.used_date AS DATE) BETWEEN @start_date AND @end_date
            GROUP BY sc.category_name
            ORDER BY SUM(su.total_price) DESC;
        
        OPEN service_revenue_cursor;
        FETCH NEXT FROM service_revenue_cursor INTO @service_category, @service_revenue;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @service_breakdown = @service_breakdown + CHAR(13) + CHAR(10) + '    ' +
                @service_category + ': $' + FORMAT(@service_revenue, 'N2');
            SET @total_service_revenue = @total_service_revenue + @service_revenue;
            
            FETCH NEXT FROM service_revenue_cursor INTO @service_category, @service_revenue;
        END
        
        CLOSE service_revenue_cursor;
        DEALLOCATE service_revenue_cursor;
        
        -- CURSOR 3: Payments by Method
        DECLARE payment_cursor CURSOR FOR
            SELECT 
                payment_method,
                SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) AS total,
                COUNT(CASE WHEN amount > 0 THEN 1 END) AS payment_count
            FROM PAYMENTS
            WHERE status = 'Completed'
            AND CAST(payment_date AS DATE) BETWEEN @start_date AND @end_date
            GROUP BY payment_method
            ORDER BY SUM(amount) DESC;
        
        OPEN payment_cursor;
        FETCH NEXT FROM payment_cursor INTO @payment_method, @payment_total, @payment_count;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @payment_breakdown = @payment_breakdown + CHAR(13) + CHAR(10) + '    ' +
                @payment_method + ': $' + FORMAT(@payment_total, 'N2') + ' (' + CAST(@payment_count AS NVARCHAR) + ' transactions)';
            SET @total_payments = @total_payments + @payment_total;
            
            FETCH NEXT FROM payment_cursor INTO @payment_method, @payment_total, @payment_count;
        END
        
        CLOSE payment_cursor;
        DEALLOCATE payment_cursor;
        
        -- Build summary output
        SET @summary_output = 
'╔══════════════════════════════════════════════════════════════╗
║              MONTHLY REVENUE SUMMARY REPORT                   ║
║                ' + DATENAME(MONTH, @start_date) + ' ' + CAST(@year AS NVARCHAR) + '                                 ║
╠══════════════════════════════════════════════════════════════╣

  ROOM REVENUE BY TYPE
  ─────────────────────────────────────────────────────────────' +
  @room_breakdown + '
  
  Total Room Revenue: $' + FORMAT(@total_room_revenue, 'N2') + '

  SERVICE REVENUE BY CATEGORY
  ─────────────────────────────────────────────────────────────' +
  @service_breakdown + '
  
  Total Service Revenue: $' + FORMAT(@total_service_revenue, 'N2') + '

  PAYMENTS BY METHOD
  ─────────────────────────────────────────────────────────────' +
  @payment_breakdown + '
  
  Total Payments Collected: $' + FORMAT(@total_payments, 'N2') + '

  ═══════════════════════════════════════════════════════════════
  GRAND TOTAL REVENUE: $' + FORMAT(@total_room_revenue + @total_service_revenue, 'N2') + '
╚══════════════════════════════════════════════════════════════╝';
        
        SET @message = 'Monthly revenue summary generated for ' + DATENAME(MONTH, @start_date) + ' ' + CAST(@year AS NVARCHAR);
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        SET @summary_output = NULL;
        SET @message = 'Error: ' + ERROR_MESSAGE();
        RETURN -1;
    END CATCH
END;
GO

PRINT 'Khanh Cursor Procedures created successfully.';
GO
