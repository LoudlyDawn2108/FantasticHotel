# Role-Based Access Control (RBAC)
## Hotel Management System

---

## 1. Role Hierarchy

| Level | Role | Description |
|-------|------|-------------|
| 100 | Administrator | Full system access |
| 90 | General Manager | All operations and reports |
| 70 | Front Desk Manager | Front desk operations management |
| 70 | Finance Manager | Payment and financial management |
| 70 | Maintenance Manager | Maintenance and staff management |
| 50 | Receptionist | Customer-facing operations |
| 50 | Cashier | Payment processing |
| 30 | Housekeeping Staff | Room cleaning operations |
| 30 | Maintenance Staff | Maintenance task completion |
| 30 | F&B Staff | Food & beverage service |
| 10 | Guest | Self-service only |

---

## 2. Table Access Matrix

### Legend
- **C** = Create | **R** = Read | **U** = Update | **D** = Delete
- **Own** = Only own records | **Dept** = Department scope | **All** = All records

### CUSTOMERS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | - | All |
| Front Desk Manager | ✓ | ✓ | ✓ | - | All |
| Receptionist | ✓ | ✓ | - | - | All |
| Cashier | - | ✓ | - | - | All |
| Guest | - | ✓ | ✓ | - | Own |

### ROOMS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | ✓ | All |
| Front Desk Manager | - | ✓ | ✓ | - | All |
| Receptionist | - | ✓ | - | - | All |
| Housekeeping Staff | - | ✓ | ✓ | - | Assigned |
| Maintenance Staff | - | ✓ | ✓ | - | Assigned |
| Guest | - | ✓ | - | - | All |

### RESERVATIONS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | ✓ | All |
| Front Desk Manager | ✓ | ✓ | ✓ | ✓ | All |
| Receptionist | ✓ | ✓ | ✓ | - | All |
| Cashier | - | ✓ | - | - | All |
| Guest | ✓ | ✓ | ✓ | - | Own |

### PAYMENTS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| Finance Manager | ✓ | ✓ | ✓ | - | All |
| Cashier | ✓ | ✓ | - | - | All |
| Guest | - | ✓ | - | - | Own |

### SERVICES_USED

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | ✓ | All |
| F&B Staff | ✓ | ✓ | ✓ | - | All |
| Receptionist | - | ✓ | - | - | All |
| Guest | - | ✓ | - | - | Own |

### MAINTENANCE_REQUESTS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| Maintenance Manager | ✓ | ✓ | ✓ | - | All |
| Maintenance Staff | - | ✓ | ✓ | - | Assigned |
| Housekeeping Staff | ✓ | ✓ | - | - | All |
| Receptionist | ✓ | ✓ | - | - | All |

### EMPLOYEES

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | - | All |
| Department Manager | - | ✓ | - | - | Dept |
| Staff | - | ✓ | - | - | Own |

### EMPLOYEE_SHIFTS

| Role | C | R | U | D | Scope |
|------|---|---|---|---|-------|
| Administrator | ✓ | ✓ | ✓ | ✓ | All |
| General Manager | ✓ | ✓ | ✓ | - | All |
| Department Manager | ✓ | ✓ | ✓ | - | Dept |
| Staff | - | ✓ | - | - | Own |

---

## 3. Procedure Authorization

### Reservation Management (Member 1 - Phuc)

| Procedure | Min Level | Notes |
|-----------|-----------|-------|
| `sp_create_reservation` | 10 | Guest can book own, Staff can book any |
| `sp_cancel_reservation` | 10 | Guest can cancel own, Staff can cancel any |
| `sp_process_daily_checkins` | 50 | Receptionist+ only |
| `sp_process_noshow_reservations` | 50 | Receptionist+ only |

### Payment Management (Member 2 - Khanh)

| Procedure | Min Level | Notes |
|-----------|-----------|-------|
| `sp_process_payment` | 50 | Cashier+ only |
| `sp_generate_invoice` | 50 | Cashier+ only |
| `sp_send_payment_reminders` | 70 | Manager+ only |
| `sp_generate_monthly_revenue_summary` | 70 | Manager+ only |

### Customer Management (Member 3 - Ninh)

| Procedure | Min Level | Notes |
|-----------|-----------|-------|
| `sp_register_customer` | 50 | Receptionist+ only |
| `sp_add_service_to_reservation` | 30 | F&B Staff+ only |
| `sp_process_loyalty_tier_upgrades` | 70 | Manager+ only |
| `sp_generate_service_usage_report` | 70 | Manager+ only |

### Operations Management (Member 4 - Tung)

| Procedure | Min Level | Notes |
|-----------|-----------|-------|
| `sp_create_maintenance_request` | 30 | Staff+ can report issues |
| `sp_complete_maintenance` | 30 | Maintenance Staff+ only |
| `sp_auto_assign_maintenance_tasks` | 70 | Maintenance Manager+ only |
| `sp_generate_employee_shift_schedule` | 70 | Manager+ only |

---

## 4. View Authorization

| View | Min Level | Roles |
|------|-----------|-------|
| `vw_room_availability` | 10 | All users |
| `vw_occupancy_statistics` | 70 | Manager+ |
| `vw_customer_history` | 50 | Receptionist+ or Guest (own) |
| `vw_popular_services` | 70 | Manager+ |
| `vw_daily_revenue_report` | 70 | Finance Manager+, GM+ |
| `vw_outstanding_payments` | 70 | Finance Manager+, GM+ |
| `vw_maintenance_dashboard` | 30 | Maintenance Staff+ |
| `vw_employee_performance` | 70 | Manager+ |

---

## 5. Authorization Functions

### fn_get_user_role_level(@user_id)
Returns the role level (10-100) for a given user.

### fn_user_can_access(@user_id, @min_level)
Returns 1 if user's role level >= min_level, 0 otherwise.

### fn_user_has_role(@user_id, @role_name)
Returns 1 if user has the specified role, 0 otherwise.

---

## 6. Authorization Pattern in Procedures

All protected procedures check authorization at the start:

```sql
-- Check minimum access level
IF dbo.fn_get_user_role_level(@user_id) < 50
BEGIN
    SET @message = 'Access denied. Insufficient permissions.';
    RETURN -403;
END

-- For guest access to own records only
IF dbo.fn_get_user_role_level(@user_id) < 50 
   AND @customer_id <> (SELECT customer_id FROM USER_ACCOUNTS WHERE user_id = @user_id)
BEGIN
    SET @message = 'Access denied. You can only access your own records.';
    RETURN -403;
END
```

---

## 7. Default Test Accounts

| Username | Role | Level | Password |
|----------|------|-------|----------|
| admin | Administrator | 100 | Password123 |
| manager | General Manager | 90 | Password123 |
| reception1 | Receptionist | 50 | Password123 |
| cashier1 | Cashier | 50 | Password123 |
| guest1 | Guest | 10 | Password123 |
