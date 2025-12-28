# Hotel Management System Database

A comprehensive SQL Server database project for a Hotel Management System, designed for a 4-person team.

## 📁 Project Structure

```
btl/
├── 01_schema/
│   ├── 01_create_database.sql      # Database creation
│   ├── 02_create_tables.sql        # All table definitions (14 tables)
│   └── 03_insert_sample_data.sql   # Sample data for testing
├── 02_procedures/
│   ├── member1_reservation_procedures.sql
│   ├── member2_payment_procedures.sql
│   ├── member3_customer_procedures.sql
│   └── member4_operations_procedures.sql
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
│   └── test_all_objects.sql        # Test script for all objects
└── README.md
```

## 🚀 Installation

Run the SQL files in this order:

1. `01_schema/01_create_database.sql`
2. `01_schema/02_create_tables.sql`
3. `01_schema/03_insert_sample_data.sql`
4. `05_functions/*` (Functions first - they're used by other objects)
5. `03_views/*`
6. `04_triggers/*`
7. `02_procedures/*`
8. `06_tests/test_all_objects.sql` (Optional - to verify everything works)

## 👥 Team Distribution

### Member 1: Reservation & Room Management
| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_create_reservation` | Creates reservation with validation, pricing, availability check |
| Procedure | `sp_cancel_reservation` | Cancels booking with refund calculation |
| View | `vw_room_availability` | Real-time room availability status |
| View | `vw_occupancy_statistics` | Occupancy rates and RevPAR metrics |
| Trigger | `trg_reservation_status_change` | Updates room status on check-in/out |
| Trigger | `trg_reservation_audit` | Logs all reservation changes |
| Function | `fn_calculate_room_price` | Calculates price with seasonal rates |
| Function | `fn_check_room_availability` | Checks if room is available |
| Function | `fn_calculate_discount_rate` | Calculates discount by tier |

### Member 2: Payment & Financial Management
| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_process_payment` | Processes payment with loyalty points |
| Procedure | `sp_generate_invoice` | Creates detailed invoice with cursor |
| View | `vw_daily_revenue_report` | Revenue breakdown by type/method |
| View | `vw_outstanding_payments` | Unpaid balances with aging |
| Trigger | `trg_payment_loyalty_update` | Updates loyalty on payment |
| Trigger | `trg_payment_audit` | Logs all payment transactions |
| Function | `fn_calculate_total_bill` | Calculates complete bill |
| Function | `fn_calculate_loyalty_points` | Points calculation with tier bonus |
| Function | `fn_get_customer_tier` | Determines tier by spending |

### Member 3: Customer & Service Management
| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_register_customer` | Registers customer with validation |
| Procedure | `sp_add_service_to_reservation` | Adds services to active stay |
| View | `vw_customer_history` | Complete customer profile |
| View | `vw_popular_services` | Service analytics and trends |
| Trigger | `trg_customer_tier_upgrade` | Auto-upgrades membership tier |
| Trigger | `trg_service_usage_notification` | Alerts for high-value services |
| Function | `fn_get_customer_discount_rate` | Discount by tier and points |
| Function | `fn_get_customer_statistics` | Comprehensive customer stats |

### Member 4: Operations & HR Management
| Type | Name | Description |
|------|------|-------------|
| Procedure | `sp_create_maintenance_request` | Creates request with auto-assignment |
| Procedure | `sp_complete_maintenance` | Completes with metrics |
| View | `vw_maintenance_dashboard` | Active requests with SLA status |
| View | `vw_employee_performance` | Staff metrics and workload |
| Trigger | `trg_room_status_history` | Tracks room status changes |
| Trigger | `trg_high_priority_maintenance` | Alerts for urgent maintenance |
| Function | `fn_calculate_room_turnaround_time` | Room cleaning metrics |
| Function | `fn_get_available_staff` | Available staff count |
| Function | `fn_get_maintenance_statistics` | Maintenance analytics |

## 📊 Database Schema

### Core Tables (14 total)
- **CUSTOMERS** - Guest information and loyalty
- **ROOM_TYPES** - Room categories and pricing
- **ROOMS** - Individual room records
- **RESERVATIONS** - Booking records
- **PAYMENTS** - Financial transactions
- **SERVICES** - Available services
- **SERVICE_CATEGORIES** - Service groupings
- **SERVICES_USED** - Service consumption
- **DEPARTMENTS** - Hotel departments
- **EMPLOYEES** - Staff records
- **EMPLOYEE_SHIFTS** - Work schedules
- **MAINTENANCE_REQUESTS** - Room maintenance
- **REVIEWS** - Guest reviews
- **AUDIT_LOGS** - System audit trail
- **ROOM_STATUS_HISTORY** - Status tracking
- **NOTIFICATIONS** - System notifications

## ✨ Advanced Features

- **Transaction Handling**: All procedures use `BEGIN TRY/CATCH` with proper rollback
- **Cursor Usage**: Invoice generation uses cursors for line items
- **Audit Logging**: Comprehensive audit trails for reservations and payments
- **Automatic Notifications**: Triggers create notifications for important events
- **SLA Tracking**: Maintenance dashboard tracks SLA compliance
- **Loyalty System**: Automatic tier upgrades and point calculations
- **Seasonal Pricing**: Dynamic room pricing based on season/weekends

## 🧪 Testing

Run `06_tests/test_all_objects.sql` to verify all objects work correctly.

## 📝 License

Academic project for SQL Database course.
