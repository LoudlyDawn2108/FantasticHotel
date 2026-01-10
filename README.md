# Hotel Management System Database

A comprehensive SQL Server database project for a Hotel Management System, designed for a 4-person team.

## 📁 Project Structure

```
btl/
├── 01_schema/
│   ├── 01_create_database.sql          # Database creation
│   ├── 02_create_tables.sql            # All table definitions (16 tables)
│   └── 03_insert_sample_data.sql       # All sample data
├── 02_procedures/
│   ├── member1_reservation_procedures.sql
│   ├── member1_cursor_procedures.sql   # 2 Cursors for reservations
│   ├── member2_payment_procedures.sql
│   ├── member2_cursor_procedures.sql   # 2 Cursors for payments
│   ├── member3_customer_procedures.sql
│   ├── member3_cursor_procedures.sql   # 2 Cursors for customers
│   ├── member4_operations_procedures.sql
│   └── security_auth_procedures.sql    # Authentication procedures (Shared)
├── 03_views/
│   ├── member1_room_views.sql
│   ├── member2_financial_views.sql
│   ├── member3_customer_views.sql
│   └── member4_operations_views.sql
├── 04_triggers/
│   ├── member1_reservation_triggers.sql
│   ├── member2_payment_triggers.sql
│   ├── member3_customer_triggers.sql
│   └── member4_operations_triggers.sql
├── 05_functions/
│   ├── member1_room_functions.sql
│   ├── member2_payment_functions.sql
│   ├── member3_customer_functions.sql
│   └── member4_operations_functions.sql
├── 06_tests/
│   └── test_all_objects.sql            # Test script for all objects
├── 07_cursors/                         # Standalone cursors
│   └── member4_operations_cursor.sql   # Tung - Operations cursors
├── BUSINESS_PROCESSES.md               # Business process documentation
├── MEMBER_BUSINESS_PROCESS_VERIFICATION.md  # Process verification
├── DATABASE_SCHEMA.dbml                # dbdiagram.io schema code
└── README.md
```

## 🚀 Installation

Run the SQL files in this order:

1. `01_schema/01_create_database.sql`
2. `01_schema/02_create_tables.sql` (includes auth tables)
3. `05_functions/*` (All function files)
4. `03_views/*`
5. `04_triggers/*`
6. `02_procedures/*` (All procedure files)
7. `01_schema/03_insert_sample_data.sql` (includes auth sample users)
8. `06_tests/test_all_objects.sql` (Optional)

---

## 🔐 Authentication & Authorization (Shared Module)

Simple **Role-Based Access Control** with one role per user.

### Authentication Tables (2 tables)

| Table | Description |
|-------|-------------|
| `ROLES` | System roles with access levels (10-100) |
| `USER_ACCOUNTS` | User credentials with single role assignment |

### Procedures & Functions

| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_create_user_account` | Creates user with role |
| Procedure | `sp_user_login` | Authenticates, returns role info |
| Procedure | `sp_change_password` | Changes own password |
| Procedure | `sp_change_user_role` | Changes user's role (manager+) |
| Procedure | `sp_unlock_user` | Unlocks locked account |
| Function | `fn_hash_password` | SHA-256 password hashing |
| Function | `fn_user_has_role` | Checks user's role |
| Function | `fn_user_can_access` | Checks minimum access level |
| Function | `fn_get_user_role_level` | Gets user's access level |

### Roles (Access Levels)

| Role | Level | Description |
|------|-------|-------------|
| Administrator | 100 | Full access |
| General Manager | 90 | All operations |
| Managers | 70 | Department management |
| Staff | 50 | Customer-facing roles |
| Operational | 30 | Internal operations |
| Guest | 10 | Self-service only |

### Test Accounts (Password: `Password123`)

| Username | Role | Level |
|----------|------|-------|
| admin | Administrator | 100 |
| manager | General Manager | 90 |
| reception1 | Receptionist | 50 |
| cashier1 | Cashier | 50 |
| guest1 | Guest | 10 |

---

## 👥 Team Distribution

Each member has: **2 Procedures** + **2 Cursors** + **2 Views** + **2 Triggers** + **2-3 Functions**

---

### Phuc: Reservation & Room Management
**Business Process:** Complete Reservation Lifecycle

| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_create_reservation` | Creates reservation with validation, pricing, availability check |
| Procedure | `sp_cancel_reservation` | Cancels booking with refund calculation |
| **Cursor** | `sp_process_daily_checkins` | Batch processes today's expected arrivals |
| **Cursor** | `sp_process_noshow_reservations` | Handles guests who didn't check in |
| View | `vw_room_availability` | Real-time room availability status |
| View | `vw_occupancy_statistics` | Occupancy rates and RevPAR metrics |
| Trigger | `trg_reservation_status_change` | Updates room status on check-in/out |
| Trigger | `trg_reservation_audit` | Logs all reservation changes |
| Function | `fn_calculate_room_price` | Calculates price with seasonal rates |
| Function | `fn_check_room_availability` | Checks if room is available |
| Function | `fn_calculate_discount_rate` | Calculates discount by tier |

---

### Khanh: Payment & Financial Management
**Business Process:** Complete Payment Lifecycle

| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_process_payment` | Processes payment with loyalty points |
| Procedure | `sp_generate_invoice` | Creates detailed invoice (uses cursor internally) |
| **Cursor** | `sp_send_payment_reminders` | Sends reminders for overdue payments |
| **Cursor** | `sp_generate_monthly_revenue_summary` | Compiles monthly financial report |
| View | `vw_daily_revenue_report` | Revenue breakdown by type/method |
| View | `vw_outstanding_payments` | Unpaid balances with aging |
| Trigger | `trg_payment_loyalty_update` | Updates loyalty on payment |
| Trigger | `trg_payment_audit` | Logs all payment transactions |
| Function | `fn_calculate_total_bill` | Calculates complete bill |
| Function | `fn_calculate_loyalty_points` | Points calculation with tier bonus |
| Function | `fn_get_customer_tier` | Determines tier by spending |

---

### Ninh: Customer & Service Management
**Business Process:** Complete Customer & Service Lifecycle

| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_register_customer` | Registers customer with validation |
| Procedure | `sp_add_service_to_reservation` | Adds services to active stay |
| **Cursor** | `sp_process_loyalty_tier_upgrades` | Batch upgrades eligible customers |
| **Cursor** | `sp_generate_service_usage_report` | Analyzes service usage patterns |
| View | `vw_customer_history` | Complete customer profile |
| View | `vw_popular_services` | Service analytics and trends |
| Trigger | `trg_customer_tier_upgrade` | Auto-upgrades membership tier |
| Trigger | `trg_service_usage_notification` | Alerts for high-value services |
| Function | `fn_get_customer_discount_rate` | Discount by tier and points |
| Function | `fn_get_customer_statistics` | Comprehensive customer stats |

---

### Tung: Operations & HR Management
**Business Process:** Complete Operations Lifecycle

| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_create_maintenance_request` | Tạo yêu cầu bảo trì + tự động phân công |
| Procedure | `sp_complete_maintenance` | Hoàn thành bảo trì với metrics |
| **Cursor** | Con trỏ 1 | Tự động phân công task chưa có người xử lý |
| **Cursor** | Con trỏ 2 | Thống kê số task theo nhân viên |
| View | `vw_maintenance_dashboard` | Dashboard bảo trì (**gọi fn_calculate_sla_status**) |
| View | `vw_employee_performance` | Thống kê hiệu suất nhân viên |
| View | `vw_maintenance_cost_statistics` | Thống kê chi phí ngày/tháng/quý/năm (**gọi fn_calculate_maintenance_cost**) |
| Trigger | `trg_room_status_history` | Ghi lịch sử thay đổi trạng thái phòng |
| Trigger | `trg_update_employee_availability` | Đánh dấu nhân viên bận khi giao task |
| Trigger | `trg_restore_employee_availability` | Khôi phục trạng thái rảnh khi hoàn thành |
| Function | `fn_calculate_sla_status` | Tính trạng thái SLA (**dùng trong View**) |
| Function | `fn_calculate_maintenance_cost` | Tính tổng chi phí bảo trì (**dùng trong View**) |

---

## 📊 Summary Statistics

| Item | Count |
|------|-------|
| Core Tables | 14 |
| **Auth Tables** | **2** |
| Stored Procedures | 8 |
| **Auth Procedures** | **5** |
| Cursor Procedures | 8 (2 per member) |
| Views | 8 |
| Triggers | 8 |
| Functions | 12 + 4 auth |
| **Total Tables** | **16** |
| **Total Objects** | **47+** |

## 💼 Business Process Integration

Each member's objects form a **complete, cohesive business process**:

1. **Phuc**: Reservation lifecycle from inquiry → booking → check-in → no-show handling
2. **Khanh**: Payment lifecycle from billing → payment → reminders → reporting
3. **Ninh**: Customer lifecycle from registration → services → tier upgrades → analytics
4. **Tung**: Operations lifecycle from issue → assignment → completion → HR scheduling

See `MEMBER_BUSINESS_PROCESS_VERIFICATION.md` for detailed process flow diagrams.

## ✨ Advanced Features

- **Authentication & Authorization**: Complete RBAC with roles, permissions, sessions
- **Password Security**: SHA-256 hashing with salt, lockout after failed attempts
- **Session Management**: Token-based sessions with expiration
- **Transaction Handling**: All procedures use `BEGIN TRY/CATCH` with proper rollback
- **Cursor Usage**: 8 cursor-based procedures for batch processing and complex reports
- **Audit Logging**: Comprehensive audit trails for reservations, payments, and logins
- **Automatic Notifications**: Triggers create notifications for important events
- **SLA Tracking**: Maintenance dashboard tracks SLA compliance
- **Loyalty System**: Automatic tier upgrades and point calculations
- **Seasonal Pricing**: Dynamic room pricing based on season/weekends
- **Batch Processing**: Daily check-in, no-show, and tier upgrade processing

## 🧪 Testing

Run `06_tests/test_all_objects.sql` to verify all objects work correctly.

## 📄 Documentation Files

- `README.md` - This file (overview and quick reference)
- `USER_REQUIREMENTS.md` - Detailed user requirements and database mapping
- `BUSINESS_PROCESSES.md` - Business process & use case documentation
- `MEMBER_BUSINESS_PROCESS_VERIFICATION.md` - Process flow diagrams per member
- `DATABASE_SCHEMA.dbml` - Schema code for dbdiagram.io

## 📝 License

Academic project for SQL Database course.
