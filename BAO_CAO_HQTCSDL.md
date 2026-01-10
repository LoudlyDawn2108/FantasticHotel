# BÁO CÁO BÀI TẬP LỚN - HỆ QUẢN TRỊ CƠ SỞ DỮ LIỆU
## ĐỀ TÀI: QUẢN LÝ KHÁCH SẠN

---

# PHẦN I: THIẾT KẾ CSDL

## 1. Bài toán đặt ra

Trong ngành khách sạn hiện đại, việc quản lý vận hành thủ công gây ra nhiều bất cập như: thông tin phòng không đồng bộ, đặt phòng trùng lặp, thanh toán sai sót, và khó theo dõi lịch sử khách hàng.

**Hệ thống Quản lý Khách sạn (Hotel Management System - HMS)** được xây dựng nhằm giải quyết các vấn đề trên cho khách sạn quy mô vừa (50-200 phòng), với các mục tiêu:

- **Quản lý phòng**: Theo dõi trạng thái phòng (Available, Occupied, Maintenance, Cleaning), loại phòng, giá theo mùa/cuối tuần
- **Quản lý đặt phòng**: Tạo, sửa, hủy đặt phòng; xử lý check-in/check-out; phát hiện no-show
- **Quản lý thanh toán**: Xử lý thanh toán đa phương thức, hoàn tiền, theo dõi công nợ
- **Quản lý khách hàng**: Đăng ký khách, tích điểm, phân hạng thành viên (Bronze/Silver/Gold/Platinum)
- **Quản lý dịch vụ**: Ghi nhận dịch vụ sử dụng, tính chi phí dịch vụ vào hóa đơn
- **Quản lý vận hành**: Yêu cầu bảo trì, phân công nhân viên, theo dõi SLA
- **Quản lý nhân sự**: Ca làm việc, hiệu suất nhân viên

---

## 2. Quy tắc quản lý & Ràng buộc

### 2.1. Ràng buộc khóa chính (Primary Key)

| Bảng | Khóa chính | Kiểu dữ liệu |
|------|------------|--------------|
| DEPARTMENTS | department_id | INT IDENTITY(1,1) |
| SERVICE_CATEGORIES | category_id | INT IDENTITY(1,1) |
| ROOM_TYPES | type_id | INT IDENTITY(1,1) |
| CUSTOMERS | customer_id | INT IDENTITY(1,1) |
| EMPLOYEES | employee_id | INT IDENTITY(1,1) |
| ROOMS | room_id | INT IDENTITY(1,1) |
| SERVICES | service_id | INT IDENTITY(1,1) |
| RESERVATIONS | reservation_id | INT IDENTITY(1,1) |
| PAYMENTS | payment_id | INT IDENTITY(1,1) |
| SERVICES_USED | usage_id | INT IDENTITY(1,1) |
| MAINTENANCE_REQUESTS | request_id | INT IDENTITY(1,1) |
| EMPLOYEE_SHIFTS | shift_id | INT IDENTITY(1,1) |
| ROOM_STATUS_HISTORY | history_id | INT IDENTITY(1,1) |
| AUDIT_LOGS | log_id | INT IDENTITY(1,1) |
| ROLES | role_id | INT IDENTITY(1,1) |
| USER_ACCOUNTS | user_id | INT IDENTITY(1,1) |

### 2.2. Ràng buộc khóa ngoại (Foreign Key)

| Bảng | Cột | Tham chiếu đến |
|------|-----|----------------|
| EMPLOYEES | department_id | DEPARTMENTS(department_id) |
| ROOMS | type_id | ROOM_TYPES(type_id) |
| SERVICES | category_id | SERVICE_CATEGORIES(category_id) |
| RESERVATIONS | customer_id | CUSTOMERS(customer_id) |
| RESERVATIONS | room_id | ROOMS(room_id) |
| PAYMENTS | reservation_id | RESERVATIONS(reservation_id) |
| PAYMENTS | customer_id | CUSTOMERS(customer_id) |
| SERVICES_USED | reservation_id | RESERVATIONS(reservation_id) |
| SERVICES_USED | service_id | SERVICES(service_id) |
| MAINTENANCE_REQUESTS | room_id | ROOMS(room_id) |
| MAINTENANCE_REQUESTS | assigned_to | EMPLOYEES(employee_id) |
| EMPLOYEE_SHIFTS | employee_id | EMPLOYEES(employee_id) |

### 2.3. Ràng buộc CHECK

| Bảng | Ràng buộc | Mô tả |
|------|-----------|-------|
| ROOM_TYPES | base_price > 0 | Giá phòng phải lớn hơn 0 |
| ROOM_TYPES | capacity > 0 | Sức chứa phải lớn hơn 0 |
| CUSTOMERS | loyalty_points >= 0 | Điểm tích lũy không âm |
| CUSTOMERS | membership_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum') | Hạng thành viên hợp lệ |
| ROOMS | status IN ('Available', 'Occupied', 'Maintenance', 'Cleaning', 'Reserved') | Trạng thái phòng hợp lệ |
| RESERVATIONS | num_guests > 0 | Số khách phải lớn hơn 0 |
| RESERVATIONS | check_out_date > check_in_date | Ngày trả phải sau ngày nhận |
| PAYMENTS | amount > 0 | Số tiền phải lớn hơn 0 |
| MAINTENANCE_REQUESTS | priority IN ('Low', 'Medium', 'High', 'Critical') | Độ ưu tiên hợp lệ |

### 2.4. Công thức tính toán

| Công thức | Mô tả |
|-----------|-------|
| room_charge = base_price × nights × seasonal × weekend | Tính tiền phòng |
| discount_amount = room_charge × discount_rate | Giảm giá theo hạng |
| tax_amount = (room_charge + service_charge - discount) × 0.10 | Thuế 10% |
| total_amount = room_charge + service_charge - discount + tax | Tổng hóa đơn |
| loyalty_points = (amount / 10) × tier_multiplier | Điểm tích lũy |

---

## 3. Mô hình Thực thể - Liên kết (ER Model)

*[Chèn ảnh sơ đồ ER - export từ dbdiagram.io bằng file DATABASE_SCHEMA.dbml]*

---

## 4. Mô hình Quan hệ (Relational Model)

**Nhóm Lookup:** DEPARTMENTS, SERVICE_CATEGORIES, ROOM_TYPES

**Nhóm Core:** CUSTOMERS, EMPLOYEES, ROOMS, SERVICES

**Nhóm Transactions:** RESERVATIONS, PAYMENTS, SERVICES_USED

**Nhóm Operations:** MAINTENANCE_REQUESTS, EMPLOYEE_SHIFTS

**Nhóm Audit:** ROOM_STATUS_HISTORY, AUDIT_LOGS

**Nhóm Security:** ROLES, USER_ACCOUNTS

---

# PHẦN II: QUẢN TRỊ CSDL

---

## NGUYỄN HỒNG PHÚC (Member 1): QUẢN LÝ ĐẶT PHÒNG & BÁN HÀNG

### 1. FUNCTION

#### 1.1. fn_calculate_room_price
- **Mục đích**: Tính giá phòng theo mùa và cuối tuần
- **Tham số**: @room_id INT, @checkin DATE, @checkout DATE
- **Trả về**: DECIMAL(10,2) - Tổng tiền phòng
- **Logic**: Mùa cao điểm (T6-8,12): +20%, Thấp (T1-2,11): -10%, Cuối tuần: +15%

#### 1.2. fn_check_room_availability
- **Mục đích**: Kiểm tra phòng có sẵn trong khoảng thời gian
- **Tham số**: @room_id INT, @checkin DATE, @checkout DATE
- **Trả về**: BIT (1=Sẵn, 0=Không sẵn)

#### 1.3. fn_calculate_discount_rate
- **Mục đích**: Tính tỷ lệ giảm giá dựa trên hạng thành viên
- **Tham số**: @tier NVARCHAR(20), @amount DECIMAL(10,2)
- **Trả về**: DECIMAL(5,2) - Phần trăm giảm giá
- **Logic**: Platinum:15%, Gold:10%, Silver:5%, Bronze:0%, Đơn>=1000$:+2%

### 2. VIEW

#### 2.1. vw_room_availability
- **Mục đích**: Hiển thị tình trạng phòng real-time
- **Các cột**: room_id, room_number, floor, type_name, base_price, capacity, status, availability, upcoming

#### 2.2. vw_occupancy_statistics
- **Mục đích**: Thống kê tỷ lệ lấp đầy phòng
- **Các cột**: report_date, total_rooms, occupied, occupancy_pct, total_revenue

### 3. STORED PROCEDURE

#### 3.1. sp_create_reservation
- **Mục đích**: Tạo đặt phòng với tính giá tự động
- **Tham số**: @cust_id, @room_id, @checkin, @checkout, @guests, @res_id OUTPUT
- **Transaction**: CÓ
- **Gọi function**: fn_check_room_availability

#### 3.2. sp_cancel_reservation
- **Mục đích**: Hủy đặt phòng với chính sách hoàn tiền
- **Tham số**: @res_id, @reason, @refund OUTPUT
- **Transaction**: CÓ
- **Logic hoàn tiền**: >7 ngày:100%, 3-7:75%, 1-2:50%, 0:25%

### 4. TRIGGER

#### 4.1. trg_reservation_status_change
- **Bảng**: RESERVATIONS (AFTER UPDATE)
- **Mục đích**: Tự động cập nhật trạng thái phòng
- **Logic**: CheckedIn→Occupied, CheckedOut→Cleaning, Cancelled→Available

#### 4.2. trg_reservation_audit
- **Bảng**: RESERVATIONS (AFTER INSERT, UPDATE, DELETE)
- **Mục đích**: Ghi log vào AUDIT_LOGS

### 5. CURSOR

#### 5.1. sp_process_daily_checkins
- **Mục đích**: Xử lý hàng loạt check-in trong ngày
- **OUTPUT**: @count INT

#### 5.2. sp_process_noshow_reservations
- **Mục đích**: Xử lý no-show và áp dụng phạt 25%
- **OUTPUT**: @count INT, @penalty DECIMAL

---

## NGÔ ĐỨC NAM KHÁNH (Member 2): QUẢN LÝ THANH TOÁN & TÀI CHÍNH

### 1. FUNCTION

#### 1.1. fn_calculate_total_bill
- **Mục đích**: Tính hóa đơn chi tiết cho đặt phòng
- **Tham số**: @res_id INT
- **Trả về**: TABLE (reservation_id, customer_name, room_charge, service_charge, total_amount, balance_due, payment_status)

#### 1.2. fn_calculate_loyalty_points
- **Mục đích**: Tính điểm thưởng theo tier
- **Tham số**: @amount DECIMAL, @tier NVARCHAR
- **Trả về**: INT
- **Logic**: 1 điểm/$10, Platinum:2x, Gold:1.5x, Silver:1.25x

#### 1.3. fn_get_customer_tier
- **Mục đích**: Xác định hạng từ tổng chi tiêu
- **Logic**: >=50k:Platinum, >=20k:Gold, >=5k:Silver

### 2. VIEW

#### 2.1. vw_daily_revenue_report
- **Mục đích**: Báo cáo doanh thu hàng ngày
- **Các cột**: report_date, total_payments, refunds, cash, credit_card, transactions

#### 2.2. vw_outstanding_payments
- **Mục đích**: Theo dõi công nợ chưa thanh toán
- **Các cột**: reservation_id, customer, balance, days_overdue, priority

### 3. STORED PROCEDURE

#### 3.1. sp_process_payment
- **Mục đích**: Xử lý thanh toán và cộng điểm loyalty
- **Tham số**: @res_id, @amount, @method, @pay_id OUTPUT
- **Transaction**: CÓ

#### 3.2. sp_generate_invoice
- **Mục đích**: Tạo hóa đơn với cursor duyệt dịch vụ
- **Tham số**: @res_id, @invoice OUTPUT
- **Cursor**: Duyệt SERVICES_USED

### 4. TRIGGER

#### 4.1. trg_payment_loyalty_update
- **Bảng**: PAYMENTS (AFTER INSERT)
- **Mục đích**: Tự động nâng hạng sau thanh toán
- **Gọi function**: fn_get_customer_tier

#### 4.2. trg_payment_audit
- **Bảng**: PAYMENTS (AFTER INSERT, UPDATE, DELETE)
- **Mục đích**: Ghi log giao dịch

### 5. CURSOR

#### 5.1. sp_send_payment_reminders
- **Mục đích**: Thống kê công nợ cần nhắc nhở
- **OUTPUT**: @count, @outstanding

#### 5.2. sp_generate_monthly_revenue_summary
- **Mục đích**: Báo cáo doanh thu tháng
- **Cursor 1**: Doanh thu phòng theo loại
- **Cursor 2**: Doanh thu dịch vụ theo danh mục

---

## NGUYỄN HẢI NINH (Member 3): QUẢN LÝ KHÁCH HÀNG & DỊCH VỤ

### 1. FUNCTION

#### 1.1. fn_get_customer_discount_rate
- **Mục đích**: Tính tỷ lệ giảm giá tổng hợp
- **Tham số**: @cust_id INT, @amount DECIMAL
- **Trả về**: DECIMAL(5,2) - Tối đa 25%
- **Logic**: Tier + Bonus điểm + Bonus đơn lớn

#### 1.2. fn_get_customer_statistics
- **Mục đích**: Thống kê toàn diện về khách hàng
- **Trả về**: TABLE (name, tier, points, reservations, service_spend)

### 2. VIEW

#### 2.1. vw_customer_history
- **Mục đích**: Lịch sử và thống kê khách hàng
- **Các cột**: customer_id, name, tier, loyalty_points, total_spending, reservations, stays

#### 2.2. vw_popular_services
- **Mục đích**: Xếp hạng dịch vụ theo mức độ phổ biến
- **Các cột**: service_name, category_name, usage_count, revenue

### 3. STORED PROCEDURE

#### 3.1. sp_register_customer
- **Mục đích**: Đăng ký khách mới với 100 điểm chào mừng
- **Tham số**: @fname, @lname, @email, @phone, @cust_id OUTPUT
- **Transaction**: CÓ

#### 3.2. sp_add_service_to_reservation
- **Mục đích**: Thêm dịch vụ và cập nhật hóa đơn
- **Tham số**: @res_id, @svc_id, @qty, @usage_id OUTPUT
- **Transaction**: CÓ

### 4. TRIGGER

#### 4.1. trg_customer_tier_upgrade
- **Bảng**: CUSTOMERS (AFTER UPDATE)
- **Mục đích**: Tự động nâng hạng khi chi tiêu tăng
- **Logic**: Chỉ nâng, không hạ hạng

### 5. CURSOR

#### 5.1. sp_process_loyalty_tier_upgrades
- **Mục đích**: Nâng hạng hàng loạt với điểm thưởng
- **OUTPUT**: @count
- **Bonus**: Platinum+2000, Gold+1000, Silver+500 điểm

#### 5.2. sp_generate_service_usage_report
- **Mục đích**: Báo cáo sử dụng dịch vụ
- **Tham số**: @start, @end, @output OUTPUT

---

## NGÔ QUANG TÙNG (Member 4): QUẢN LÝ VẬN HÀNH & NHÂN SỰ

### 1. FUNCTION

#### 1.1. fn_calculate_sla_status
- **Mục đích**: Tính trạng thái SLA cho yêu cầu bảo trì
- **Tham số**: @priority, @status, @created
- **Trả về**: NVARCHAR(20) - On Track, At Risk, SLA Breached, Completed
- **Được gọi bởi**: VIEW vw_maintenance_dashboard
- **Logic SLA**: Critical:4h, High:12h, Medium:24h, Low:48h

#### 1.2. fn_calculate_maintenance_cost
- **Mục đích**: Tính tổng chi phí bảo trì theo khoảng thời gian
- **Tham số**: @from_date DATE, @to_date DATE
- **Trả về**: DECIMAL(15,2)
- **Được gọi bởi**: VIEW vw_maintenance_cost_statistics

### 2. VIEW

#### 2.1. vw_maintenance_dashboard
- **Mục đích**: Dashboard tổng quan yêu cầu bảo trì
- **Các cột**: request_id, room_number, title, priority, status, assigned_to, hours_elapsed, sla_status
- **Gọi function**: fn_calculate_sla_status

#### 2.2. vw_employee_performance
- **Mục đích**: Thống kê hiệu suất nhân viên
- **Các cột**: employee_id, name, department_name, total_shifts, completed, tasks_done

#### 2.3. vw_maintenance_cost_statistics
- **Mục đích**: Thống kê chi phí bảo trì theo ngày/tuần/tháng/quý/năm
- **Các cột**: today_cost, week_cost, month_cost, quarter_cost, year_cost
- **Gọi function**: fn_calculate_maintenance_cost

### 3. STORED PROCEDURE

#### 3.1. sp_create_maintenance_request
- **Mục đích**: Tạo yêu cầu bảo trì và tự động phân công nhân viên
- **Tham số**: @room_id, @title, @priority, @req_id OUTPUT, @assigned OUTPUT
- **Transaction**: CÓ
- **Logic**: Tìm nhân viên có ít task nhất để phân công

#### 3.2. sp_complete_maintenance
- **Mục đích**: Hoàn thành bảo trì và cập nhật trạng thái phòng
- **Tham số**: @req_id, @cost, @hours OUTPUT
- **Transaction**: CÓ

### 4. TRIGGER

#### 4.1. trg_room_status_history
- **Bảng**: ROOMS (AFTER UPDATE)
- **Mục đích**: Ghi lịch sử thay đổi trạng thái phòng vào ROOM_STATUS_HISTORY

#### 4.2. trg_update_employee_availability
- **Bảng**: MAINTENANCE_REQUESTS (AFTER INSERT)
- **Mục đích**: Đánh dấu nhân viên bận khi nhận task Critical/High

#### 4.3. trg_restore_employee_availability
- **Bảng**: MAINTENANCE_REQUESTS (AFTER UPDATE)
- **Mục đích**: Khôi phục trạng thái rảnh khi hoàn thành task

### 5. CURSOR

#### 5.1. Cursor 1: Phân công tự động
- **Mục đích**: Duyệt và phân công task chưa có người xử lý
- **Logic**: Sắp xếp theo priority, tìm nhân viên rảnh để gán

#### 5.2. Cursor 2: Thống kê task
- **Mục đích**: Báo cáo khối lượng công việc đội bảo trì
- **Logic**: Đếm số task của từng nhân viên
