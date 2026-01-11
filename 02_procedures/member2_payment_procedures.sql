-- Khanh: PAYMENT PROCEDURES (Simplified)
USE HotelManagement;
GO

-- sp_process_payment: Process payment, update loyalty
CREATE OR ALTER PROCEDURE sp_process_payment
    @res_id INT, @amount DECIMAL(10,2), @method NVARCHAR(50),
    @pay_id INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cust_id INT, @total DECIMAL(10,2), @paid DECIMAL(10,2);
    DECLARE @tier NVARCHAR(20), @points INT;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @cust_id = customer_id, @total = total_amount, @paid = paid_amount
        FROM RESERVATIONS WHERE reservation_id = @res_id;
        IF @cust_id IS NULL BEGIN ROLLBACK; RETURN -1; END
        IF @amount > (@total - @paid) SET @amount = @total - @paid;        
        INSERT INTO PAYMENTS (reservation_id, customer_id, amount, payment_method, status)
        VALUES (@res_id, @cust_id, @amount, @method, 'Completed');
        SET @pay_id = SCOPE_IDENTITY();
        UPDATE RESERVATIONS SET paid_amount = paid_amount + @amount WHERE reservation_id = @res_id;
        SELECT @tier = membership_tier FROM CUSTOMERS WHERE customer_id = @cust_id;
        SET @points = FLOOR(@amount / 100) * 10 * 
            CASE @tier WHEN 'Platinum' THEN 2 WHEN 'Gold' THEN 1.5 WHEN 'Silver' THEN 1.2 ELSE 1 END;
        UPDATE CUSTOMERS SET loyalty_points = loyalty_points + @points,
            total_spending = total_spending + @amount WHERE customer_id = @cust_id;      
        COMMIT;
        RETURN 0;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @pay_id = NULL;
        RETURN -1;
    END CATCH
END;
GO

-- sp_generate_invoice: Build invoice using cursor for services
CREATE OR ALTER PROCEDURE sp_generate_invoice
    @res_id INT,
    @invoice NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cust NVARCHAR(100), @room NVARCHAR(10), @checkin DATE, @checkout DATE;
    DECLARE @total DECIMAL(10,2), @paid DECIMAL(10,2);
    DECLARE @svc_name NVARCHAR(100), @qty INT, @price DECIMAL(10,2);
    DECLARE @services NVARCHAR(MAX) = '';
    SELECT @cust = c.first_name + ' ' + c.last_name, @room = rm.room_number,
           @checkin = r.check_in_date, @checkout = r.check_out_date,
           @total = r.total_amount, @paid = r.paid_amount
    FROM RESERVATIONS r
    JOIN CUSTOMERS c ON r.customer_id = c.customer_id
    JOIN ROOMS rm ON r.room_id = rm.room_id
    WHERE r.reservation_id = @res_id;
    IF @cust IS NULL BEGIN SET @invoice = 'Not found'; RETURN -1; END
    DECLARE cur CURSOR FOR
        SELECT s.service_name, su.quantity, su.total_price
        FROM SERVICES_USED su JOIN SERVICES s ON su.service_id = s.service_id
        WHERE su.reservation_id = @res_id;
    OPEN cur;
    FETCH NEXT FROM cur INTO @svc_name, @qty, @price;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @services = @services + @svc_name + ' x' + CAST(@qty AS NVARCHAR) + 
            ' = $' + CAST(@price AS NVARCHAR) + CHAR(13);
        FETCH NEXT FROM cur INTO @svc_name, @qty, @price;
    END
    CLOSE cur; DEALLOCATE cur;
    SET @invoice = '=== INVOICE ===' + CHAR(13) +
        'Guest: ' + @cust + CHAR(13) +
        'Room: ' + @room + CHAR(13) +
        'Stay: ' + CAST(@checkin AS NVARCHAR) + ' to ' + CAST(@checkout AS NVARCHAR) + CHAR(13) +
        'Services: ' + CHAR(13) + @services +
        'Total: $' + CAST(@total AS NVARCHAR) + CHAR(13) +
        'Paid: $' + CAST(@paid AS NVARCHAR) + CHAR(13) +
        'Balance: $' + CAST(@total - @paid AS NVARCHAR);
    
    RETURN 0;
END;
GO
