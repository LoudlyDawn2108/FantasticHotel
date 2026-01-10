# User Requirements Document
## Hotel Management System

---

## 1. Introduction

### 1.1 Purpose
This document describes the user requirements for the **Hotel Management System (HMS)** database, designed to support the daily operations of a mid-sized hotel (50-200 rooms). It details the business needs from the hotel's perspective and explains how the database schema and operations fulfill each requirement.

### 1.2 Scope
The HMS covers:
- Guest reservations and room management
- Payment processing and financial reporting
- Customer relationship and service management
- Operations, maintenance, and HR management
- User authentication and authorization

### 1.3 Stakeholders
| Stakeholder | Role | Primary Needs |
|-------------|------|---------------|
| Hotel Owner/GM | Strategic oversight | Revenue reports, occupancy metrics, operational efficiency |
| Front Desk Manager | Guest services | Reservation management, room status, check-in/out |
| Finance Manager | Financial control | Payment tracking, invoices, revenue analysis |
| Housekeeping Supervisor | Room readiness | Room status updates, cleaning schedules |
| Maintenance Manager | Facility upkeep | Work orders, SLA tracking, staff assignments |
| Receptionists | Guest interaction | Bookings, check-in, customer service |
| Guests | Accommodation | Easy booking, seamless check-in, quality service |

---

## 2. Business Requirements

### 2.1 Reservation Management

#### BR-1: Room Booking
**Requirement:** The hotel must be able to accept, manage, and track room reservations from inquiry to checkout.

**User Story:** *"As a receptionist, I need to check room availability and create reservations quickly so that guests can book their stay without delays."*

**Acceptance Criteria:**
- Check real-time room availability for any date range
- Calculate accurate pricing based on room type, season, and duration
- Apply member discounts automatically
- Validate guest count against room capacity
- Generate reservation confirmation

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Check availability | `fn_check_room_availability()` | Phuc | Returns 1/0 if room is available for dates |
| View available rooms | `vw_room_availability` | Phuc | Shows all rooms with current status |
| Calculate price | `fn_calculate_room_price()` | Phuc | Dynamic pricing with seasonal rates |
| Apply discount | `fn_calculate_discount_rate()` | Phuc | Member tier-based discounts |
| Create booking | `sp_create_reservation` | Phuc | Full validation and booking creation |
| Audit trail | `trg_reservation_audit` | Phuc | Logs all reservation changes |

---

#### BR-2: Check-In/Check-Out
**Requirement:** The hotel must efficiently process guest arrivals and departures, updating room statuses automatically.

**User Story:** *"As a receptionist, I need to quickly check in arriving guests and have the room status update automatically so housekeeping knows which rooms are occupied."*

**Acceptance Criteria:**
- View today's expected arrivals
- Update reservation status to "CheckedIn"
- Automatically change room status to "Occupied"
- Process check-out and update room to "NeedsCleaning"

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Daily arrivals | `sp_process_daily_checkins` | Phuc | **CURSOR** - Batch processes expected arrivals |
| Auto room status | `trg_reservation_status_change` | Phuc | Trigger updates room on check-in/out |
| Occupancy tracking | `vw_occupancy_statistics` | Phuc | Daily occupancy rates and RevPAR |

---

#### BR-3: Cancellation & No-Shows
**Requirement:** The hotel must handle cancellations with appropriate refund policies and process no-show guests automatically.

**User Story:** *"As a manager, I need to apply cancellation policies fairly and ensure no-show rooms are released back to inventory promptly."*

**Acceptance Criteria:**
- Calculate refunds based on days until check-in
- Release cancelled rooms immediately
- Automatically process no-shows after check-in date
- Apply no-show penalties

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Cancel with refund | `sp_cancel_reservation` | Phuc | Tiered refund calculation |
| No-show processing | `sp_process_noshow_reservations` | Phuc | **CURSOR** - Batch processes no-shows |
| Room release | `trg_reservation_status_change` | Phuc | Updates room to Available |

---

### 2.2 Payment & Financial Management

#### BR-4: Payment Processing
**Requirement:** The hotel must accept and record payments accurately, update reservation balances, and maintain complete financial records.

**User Story:** *"As a cashier, I need to process payments quickly and have the system automatically update balances and award loyalty points."*

**Acceptance Criteria:**
- Accept multiple payment methods (Cash, Credit, Debit, Transfer)
- Update reservation paid amount
- Calculate and award loyalty points
- Generate payment receipts

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Process payment | `sp_process_payment` | Khanh | Records payment, updates balance |
| Loyalty points | `fn_calculate_loyalty_points()` | Khanh | Points calculation with tier bonus |
| Payment audit | `trg_payment_audit` | Khanh | Logs all payment transactions |
| Tier upgrade | `trg_payment_loyalty_update` | Khanh | Auto-upgrades customer tier |

---

#### BR-5: Invoice Generation
**Requirement:** The hotel must generate detailed invoices showing all charges for a guest's stay.

**User Story:** *"As a cashier, I need to generate a comprehensive invoice that itemizes room charges, services used, taxes, and discounts."*

**Acceptance Criteria:**
- List all room nights with rates
- Include all services consumed
- Apply applicable taxes
- Show membership discounts
- Calculate total due

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Calculate total | `fn_calculate_total_bill()` | Khanh | TVF returns itemized bill |
| Generate invoice | `sp_generate_invoice` | Khanh | Uses **CURSOR** to build invoice |

---

#### BR-6: Outstanding Payment Tracking
**Requirement:** The hotel must track unpaid balances and proactively collect outstanding payments.

**User Story:** *"As a finance manager, I need to see which guests have outstanding balances and send reminders before they become overdue."*

**Acceptance Criteria:**
- View all reservations with unpaid balances
- Categorize by aging (current, 30 days, 60 days, 90+ days)
- Send automated payment reminders
- Flag high-priority accounts

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| View outstanding | `vw_outstanding_payments` | Khanh | Aging analysis of unpaid balances |
| Send reminders | `sp_send_payment_reminders` | Khanh | **CURSOR** - Batch sends reminders |

---

#### BR-7: Financial Reporting
**Requirement:** The hotel must generate daily and monthly revenue reports for business analysis.

**User Story:** *"As a GM, I need to see daily revenue breakdowns and monthly trends to make informed business decisions."*

**Acceptance Criteria:**
- Daily revenue by room type and payment method
- Monthly revenue summaries
- Revenue trends over time

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Daily report | `vw_daily_revenue_report` | Khanh | Revenue breakdown by type |
| Monthly report | `sp_generate_monthly_revenue_summary` | Khanh | **CURSOR** - Detailed monthly analysis |

---

### 2.3 Customer & Service Management

#### BR-8: Customer Registration
**Requirement:** The hotel must maintain a customer database with contact information and loyalty program enrollment.

**User Story:** *"As a receptionist, I need to register new guests quickly and automatically enroll them in our loyalty program with welcome benefits."*

**Acceptance Criteria:**
- Capture guest information (name, contact, ID)
- Validate email and phone uniqueness
- Enroll in loyalty program at Bronze level
- Award welcome bonus points

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Register customer | `sp_register_customer` | Ninh | Validates and creates customer |
| Welcome bonus | `sp_register_customer` | Ninh | Awards 100 points on registration |
| Customer profile | `vw_customer_history` | Ninh | Complete customer overview |

---

#### BR-9: Service Management
**Requirement:** The hotel must track available services and allow staff to add service charges to guest bills.

**User Story:** *"As F&B staff, I need to easily add restaurant charges to a guest's room bill."*

**Acceptance Criteria:**
- View available services and prices
- Add services to active reservations
- Track service usage by guest
- Alert for high-value service requests

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| View services | `vw_popular_services` | Ninh | Services with usage analytics |
| Add service | `sp_add_service_to_reservation` | Ninh | Adds charge to reservation |
| High-value alert | `trg_service_usage_notification` | Ninh | Notifies for services > $200 |

---

#### BR-10: Loyalty Program
**Requirement:** The hotel must maintain a tiered loyalty program that rewards repeat guests.

**User Story:** *"As a manager, I want loyal customers to automatically receive tier upgrades and better discounts based on their spending."*

**Acceptance Criteria:**
- Four tiers: Bronze, Silver, Gold, Platinum
- Automatic tier upgrades based on total spending
- Tier-based discount rates
- Bonus points on tier upgrade

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Determine tier | `fn_get_customer_tier()` | Khanh | Calculates tier from spending |
| Get discount | `fn_get_customer_discount_rate()` | Ninh | Returns discount by tier |
| Batch upgrade | `sp_process_loyalty_tier_upgrades` | Ninh | **CURSOR** - Upgrades eligible customers |
| Auto upgrade | `trg_customer_tier_upgrade` | Ninh | Trigger-based tier upgrade |
| Customer stats | `fn_get_customer_statistics()` | Ninh | TVF with spending metrics |

---

#### BR-11: Service Analytics
**Requirement:** The hotel must analyze service usage patterns to optimize offerings.

**User Story:** *"As a manager, I want to know which services are most popular and who our top service spenders are."*

**Acceptance Criteria:**
- Service usage counts and revenue
- Category-level analysis
- Top customers by service spending

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Service popularity | `vw_popular_services` | Ninh | Ranked by usage and revenue |
| Usage report | `sp_generate_service_usage_report` | Ninh | **CURSOR** - Detailed analysis |

---

### 2.4 Operations & HR Management

#### BR-12: Maintenance Request Management
**Requirement:** The hotel must track room issues and maintenance requests from creation to resolution.

**User Story:** *"As a housekeeper, I need to report room issues quickly so maintenance can fix them before the next guest arrives."*

**Acceptance Criteria:**
- Create maintenance requests with priority
- Track request status (Pending, Assigned, InProgress, Completed)
- Measure response and resolution times
- Alert for high-priority issues

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Create request | `sp_create_maintenance_request` | Tung | Creates and optionally assigns |
| Priority alert | `trg_high_priority_maintenance` | Tung | Notifies for Critical/High priority |
| Complete task | `sp_complete_maintenance` | Tung | Marks done, updates room |
| SLA tracking | `vw_maintenance_dashboard` | Tung | Shows SLA status (On Track/At Risk/Overdue) |

---

#### BR-13: Staff Task Assignment
**Requirement:** The hotel must efficiently assign maintenance tasks to available staff.

**User Story:** *"As a maintenance manager, I want unassigned tasks to be automatically distributed to available staff based on their current workload."*

**Acceptance Criteria:**
- Check staff availability
- Balance workload across team
- Auto-assign by priority
- Track assignment history

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Check availability | `fn_get_available_staff()` | Tung | Count available by department |
| Auto-assign | `sp_auto_assign_maintenance_tasks` | Tung | **CURSOR** - Assigns by priority and workload |

---

#### BR-14: Room Status Tracking
**Requirement:** The hotel must track room status changes for operational efficiency.

**User Story:** *"As a housekeeping supervisor, I need to see when rooms change status so I can dispatch cleaning crews efficiently."*

**Acceptance Criteria:**
- Log all room status changes
- Calculate room turnaround time
- Track status history

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Log changes | `trg_room_status_history` | Tung | Trigger logs all status changes |
| Turnaround time | `fn_calculate_room_turnaround_time()` | Tung | Measures cleaning efficiency |
| Status history | `ROOM_STATUS_HISTORY` table | Core | Stores historical data |

---

#### BR-15: Employee Performance & Scheduling
**Requirement:** The hotel must track employee performance and generate work schedules.

**User Story:** *"As an HR manager, I need to track employee performance metrics and generate weekly shift schedules that balance workload fairly."*

**Acceptance Criteria:**
- View employee performance metrics
- Track attendance and workload
- Generate weekly shift schedules
- Ensure fair distribution of shifts

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| Performance view | `vw_employee_performance` | Tung | Tasks completed, attendance |
| Maintenance stats | `fn_get_maintenance_statistics()` | Tung | TVF with performance metrics |
| Generate schedule | `sp_generate_employee_shift_schedule` | Tung | **CURSOR** - Creates weekly schedule |

---

### 2.5 Authentication & Security

#### BR-16: User Authentication
**Requirement:** The system must authenticate users and protect access to sensitive operations.

**User Story:** *"As a hotel employee, I need to log in securely to access the system, and my access should be limited to my job functions."*

**Acceptance Criteria:**
- Secure login with hashed passwords
- Account lockout after failed attempts
- Role-based access levels
- Audit trail for security events

**Database Solution:**

| Requirement | Database Object | Member | Description |
|-------------|-----------------|--------|-------------|
| User accounts | `USER_ACCOUNTS` table | Shared | Stores credentials with hashed passwords |
| Login | `sp_user_login` | Shared | Validates credentials, returns role |
| Role check | `fn_user_can_access()` | Shared | Checks minimum access level |
| Password change | `sp_change_password` | Shared | Secure password update |
| Unlock account | `sp_unlock_user` | Shared | Admin function to unlock |

---

## 3. Requirements Traceability Matrix

### 3.1 By Team Member

#### Phuc: Reservation & Room Management
| BR ID | Requirement | Objects Used |
|-------|-------------|--------------|
| BR-1 | Room Booking | `sp_create_reservation`, `fn_check_room_availability`, `fn_calculate_room_price`, `fn_calculate_discount_rate`, `vw_room_availability` |
| BR-2 | Check-In/Out | `sp_process_daily_checkins` (CURSOR), `trg_reservation_status_change`, `vw_occupancy_statistics` |
| BR-3 | Cancellation/No-Show | `sp_cancel_reservation`, `sp_process_noshow_reservations` (CURSOR) |

**Cursors:** 2 (`sp_process_daily_checkins`, `sp_process_noshow_reservations`)

---

#### Khanh: Payment & Financial Management
| BR ID | Requirement | Objects Used |
|-------|-------------|--------------|
| BR-4 | Payment Processing | `sp_process_payment`, `fn_calculate_loyalty_points`, `trg_payment_audit`, `trg_payment_loyalty_update` |
| BR-5 | Invoice Generation | `sp_generate_invoice` (has cursor), `fn_calculate_total_bill` |
| BR-6 | Outstanding Tracking | `vw_outstanding_payments`, `sp_send_payment_reminders` (CURSOR) |
| BR-7 | Financial Reporting | `vw_daily_revenue_report`, `sp_generate_monthly_revenue_summary` (CURSOR) |

**Cursors:** 2 (`sp_send_payment_reminders`, `sp_generate_monthly_revenue_summary`)

---

#### Ninh: Customer & Service Management
| BR ID | Requirement | Objects Used |
|-------|-------------|--------------|
| BR-8 | Customer Registration | `sp_register_customer`, `vw_customer_history` |
| BR-9 | Service Management | `sp_add_service_to_reservation`, `vw_popular_services`, `trg_service_usage_notification` |
| BR-10 | Loyalty Program | `sp_process_loyalty_tier_upgrades` (CURSOR), `trg_customer_tier_upgrade`, `fn_get_customer_discount_rate`, `fn_get_customer_statistics` |
| BR-11 | Service Analytics | `vw_popular_services`, `sp_generate_service_usage_report` (CURSOR) |

**Cursors:** 2 (`sp_process_loyalty_tier_upgrades`, `sp_generate_service_usage_report`)

---

#### Tung: Operations & HR Management
| BR ID | Requirement | Objects Used |
|-------|-------------|--------------|
| BR-12 | Maintenance Requests | `sp_create_maintenance_request`, `sp_complete_maintenance`, `trg_high_priority_maintenance`, `vw_maintenance_dashboard` |
| BR-13 | Staff Assignment | `sp_auto_assign_maintenance_tasks` (CURSOR), `fn_get_available_staff` |
| BR-14 | Room Status | `trg_room_status_history`, `fn_calculate_room_turnaround_time` |
| BR-15 | HR & Scheduling | `vw_employee_performance`, `fn_get_maintenance_statistics`, `sp_generate_employee_shift_schedule` (CURSOR) |

**Cursors:** 2 (`sp_auto_assign_maintenance_tasks`, `sp_generate_employee_shift_schedule`)

---

### 3.2 Summary Statistics

| Member | Requirements Covered | Procedures | Views | Triggers | Functions | Cursors |
|--------|---------------------|------------|-------|----------|-----------|---------|
| Phuc | BR-1, BR-2, BR-3 | 2 | 2 | 2 | 3 | 2 |
| Khanh | BR-4, BR-5, BR-6, BR-7 | 2 | 2 | 2 | 3 | 2 |
| Ninh | BR-8, BR-9, BR-10, BR-11 | 2 | 2 | 2 | 3 | 2 |
| Tung | BR-12, BR-13, BR-14, BR-15 | 2 | 2 | 2 | 3 | 2 |
| Shared | BR-16 | 5 | - | - | 4 | - |

---

## 4. Database Schema Support

### 4.1 Core Tables (14)

| Table | Primary Purpose | Requirements Supported |
|-------|-----------------|----------------------|
| `CUSTOMERS` | Guest information and loyalty | BR-8, BR-10 |
| `ROOM_TYPES` | Room categories and base pricing | BR-1 |
| `ROOMS` | Individual rooms and status | BR-1, BR-2, BR-14 |
| `RESERVATIONS` | Booking records | BR-1, BR-2, BR-3, BR-4 |
| `PAYMENTS` | Financial transactions | BR-4, BR-5 |
| `SERVICES` | Available hotel services | BR-9 |
| `SERVICE_CATEGORIES` | Service groupings | BR-9, BR-11 |
| `SERVICES_USED` | Service consumption records | BR-5, BR-9 |
| `DEPARTMENTS` | Hotel departments | BR-13, BR-15 |
| `EMPLOYEES` | Staff records | BR-13, BR-15 |
| `EMPLOYEE_SHIFTS` | Work schedules | BR-15 |
| `MAINTENANCE_REQUESTS` | Room issues and repairs | BR-12, BR-13 |
| `REVIEWS` | Guest feedback | BR-9 |
| `AUDIT_LOGS` | System audit trail | BR-16 |
| `ROOM_STATUS_HISTORY` | Status change tracking | BR-14 |
| `NOTIFICATIONS` | System notifications | BR-12 |

### 4.2 Authentication Tables (2)

| Table | Primary Purpose | Requirements Supported |
|-------|-----------------|----------------------|
| `ROLES` | Access control levels | BR-16 |
| `USER_ACCOUNTS` | Login credentials | BR-16 |

---

## 5. Use Case Scenarios

### Scenario 1: New Guest Booking
**Actor:** Receptionist

1. Guest calls to book a room for Jan 15-18
2. Receptionist uses `vw_room_availability` to find available Deluxe rooms
3. `fn_check_room_availability(room_id, '2025-01-15', '2025-01-18')` confirms availability
4. `fn_calculate_room_price()` calculates $450 for 3 nights
5. Guest is new - `sp_register_customer` creates account with 100 bonus points
6. `sp_create_reservation` creates booking with validation
7. `trg_reservation_audit` logs the new reservation
8. Confirmation sent to guest

**Objects Used:** BR-1, BR-8

---

### Scenario 2: Guest Check-In Day
**Actor:** System (Automated), Receptionist

1. Morning: `sp_process_daily_checkins` (CURSOR) identifies 15 arrivals for today
2. Notifications created for front desk
3. Guest arrives at 3 PM
4. Receptionist updates reservation status to 'CheckedIn'
5. `trg_reservation_status_change` automatically updates room to 'Occupied'
6. `vw_occupancy_statistics` shows updated occupancy at 85%

**Objects Used:** BR-2

---

### Scenario 3: Guest Uses Hotel Services
**Actor:** F&B Staff, Guest

1. Guest orders room service dinner ($85)
2. F&B staff uses `sp_add_service_to_reservation` to add charge
3. `trg_service_usage_notification` - no alert (under $200)
4. Guest books spa treatment ($280)
5. Spa staff adds via `sp_add_service_to_reservation`
6. `trg_service_usage_notification` fires - notifies manager of high-value service
7. `fn_calculate_total_bill()` now shows $815 total (room + services)

**Objects Used:** BR-9

---

### Scenario 4: Payment and Checkout
**Actor:** Cashier, Guest

1. Guest requests checkout and invoice
2. Cashier runs `sp_generate_invoice` (CURSOR iterates through charges)
3. Invoice shows: Room $450, Dinner $85, Spa $280, Tax $65 = **$880**
4. Guest pays by credit card
5. `sp_process_payment` records payment
6. `fn_calculate_loyalty_points()` awards 88 points (10% of spend)
7. `trg_payment_audit` logs transaction
8. Guest now has 188 total points - triggers `trg_customer_tier_upgrade` - upgraded to Silver!
9. Notification sent congratulating tier upgrade

**Objects Used:** BR-4, BR-5, BR-10

---

### Scenario 5: Maintenance Issue
**Actor:** Housekeeping, Maintenance Staff

1. Housekeeping finds AC not working in Room 301
2. Creates request via `sp_create_maintenance_request` with priority 'High'
3. `trg_high_priority_maintenance` fires - notifies maintenance manager
4. `sp_auto_assign_maintenance_tasks` (CURSOR) assigns to technician with lowest workload
5. Technician views task on `vw_maintenance_dashboard`
6. After repair, marks complete via `sp_complete_maintenance`
7. `trg_room_status_history` logs status change
8. `fn_calculate_room_turnaround_time()` shows 45-minute response time

**Objects Used:** BR-12, BR-13, BR-14

---

### Scenario 6: End of Month Reporting
**Actor:** Finance Manager, General Manager

1. Finance Manager runs `sp_generate_monthly_revenue_summary` (CURSOR)
2. Report shows revenue by room type: Deluxe $45,000, Suite $28,000, Standard $22,000
3. `vw_outstanding_payments` reveals $3,200 in overdue receivables
4. `sp_send_payment_reminders` (CURSOR) sends 8 reminder notices
5. GM reviews `vw_occupancy_statistics` - 78% average occupancy
6. HR runs `sp_generate_employee_shift_schedule` (CURSOR) for next week

**Objects Used:** BR-6, BR-7, BR-15

---

## 6. Appendix

### 6.1 Role Access Levels
| Level | Roles | Typical Access |
|-------|-------|----------------|
| 100 | Administrator | Full system access |
| 90 | General Manager | All operations and reports |
| 70 | Department Managers | Department-specific management |
| 50 | Staff (Receptionist, Cashier) | Customer-facing operations |
| 30 | Operational Staff | Task completion |
| 10 | Guest | Self-service only |

### 6.2 Loyalty Tier Thresholds
| Tier | Min Spending | Discount | Points Multiplier |
|------|--------------|----------|-------------------|
| Bronze | $0 | 0% | 1x |
| Silver | $1,000 | 5% | 1.5x |
| Gold | $5,000 | 10% | 2x |
| Platinum | $15,000 | 15% | 3x |

### 6.3 Maintenance SLA
| Priority | Target Response | SLA Status |
|----------|-----------------|------------|
| Critical | 1 hour | On Track / Overdue |
| High | 4 hours | On Track / At Risk / Overdue |
| Medium | 24 hours | On Track / At Risk / Overdue |
| Low | 72 hours | On Track / At Risk / Overdue |

---

## 7. Table Field Rationale

This section explains why each table has its specific fields, tracing columns back to the user requirements that necessitated their creation.

---

### 7.1 CUSTOMERS Table

**Purpose:** Store guest information and loyalty program data (BR-8, BR-10)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `customer_id` | INT PK | Core | Unique identifier for referential integrity |
| `first_name` | NVARCHAR(50) | BR-8: "Capture guest information" | Required for personalized communication and identification |
| `last_name` | NVARCHAR(50) | BR-8: "Capture guest information" | Legal name for reservation records and invoices |
| `email` | NVARCHAR(100) UNIQUE | BR-8: "Validate email uniqueness" | Primary contact method, must be unique per customer |
| `phone` | NVARCHAR(20) | BR-8: "Capture contact information" | Secondary contact, required for urgent notifications |
| `id_type` | NVARCHAR(20) | BR-8: "Capture guest ID" | Legal requirement for guest registration (Passport, ID Card, etc.) |
| `id_number` | NVARCHAR(50) | BR-8: "Capture guest ID" | Government-issued ID for verification |
| `date_of_birth` | DATE | BR-8 | Age verification, birthday promotions |
| `membership_tier` | NVARCHAR(20) | BR-10: "Four tiers: Bronze, Silver, Gold, Platinum" | Current loyalty tier for discount calculation |
| `loyalty_points` | INT | BR-10: "Award points" | Accumulated points for redemption |
| `total_spending` | DECIMAL | BR-10: "Automatic tier upgrades based on spending" | Cumulative spend for tier qualification |
| `created_at` | DATETIME | Core | Track when customer was registered |
| `is_active` | BIT | Core | Soft delete, allow account deactivation |

---

### 7.2 ROOM_TYPES Table

**Purpose:** Define room categories with pricing (BR-1)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `room_type_id` | INT PK | Core | Unique identifier |
| `type_name` | NVARCHAR(50) | BR-1: "Room type" | Category name (Standard, Deluxe, Suite) |
| `description` | NVARCHAR(500) | BR-1 | Marketing description for guests |
| `base_price` | DECIMAL | BR-1: "Calculate accurate pricing" | Starting price for rate calculations |
| `max_occupancy` | INT | BR-1: "Validate guest count against capacity" | Maximum guests allowed - enforced in reservations |
| `amenities` | NVARCHAR(500) | BR-1 | Features list (WiFi, AC, TV) for guest selection |

---

### 7.3 ROOMS Table

**Purpose:** Track individual rooms and their status (BR-1, BR-2, BR-14)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `room_id` | INT PK | Core | Unique identifier |
| `room_number` | NVARCHAR(10) UNIQUE | BR-1 | Physical room identifier (e.g., "301", "A102") |
| `room_type_id` | INT FK | BR-1: "Room type" | Links to ROOM_TYPES for pricing and capacity |
| `floor` | INT | BR-2, BR-14 | Operational - housekeeping routes, guest preferences |
| `status` | NVARCHAR(20) | BR-2: "Update room status" | Current state: Available, Occupied, NeedsCleaning, Maintenance |
| `is_active` | BIT | Core | Whether room is in service (vs under renovation) |

**Status Values Rationale:**
- `Available` - BR-1: Room can be booked
- `Occupied` - BR-2: Guest has checked in
- `NeedsCleaning` - BR-2: Guest checked out, pending housekeeping
- `Maintenance` - BR-12: Room has issues being addressed
- `Reserved` - BR-1: Booked but guest not arrived

---

### 7.4 RESERVATIONS Table

**Purpose:** Core booking records (BR-1, BR-2, BR-3, BR-4)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `reservation_id` | INT PK | Core | Unique booking identifier |
| `customer_id` | INT FK | BR-1: "Create reservations" | Links booking to guest |
| `room_id` | INT FK | BR-1: "Check room availability" | Specific room assigned |
| `check_in_date` | DATE | BR-1: "Date range" | Arrival date for booking |
| `check_out_date` | DATE | BR-1: "Date range" | Departure date |
| `number_of_guests` | INT | BR-1: "Validate guest count" | Must not exceed room capacity |
| `status` | NVARCHAR(20) | BR-2, BR-3 | Booking lifecycle state |
| `total_amount` | DECIMAL | BR-1: "Calculate accurate pricing" | Total room charge |
| `discount_applied` | DECIMAL | BR-1: "Apply member discounts" | Loyalty tier discount percentage |
| `paid_amount` | DECIMAL | BR-4: "Update reservation paid amount" | Running total of payments received |
| `special_requests` | NVARCHAR(500) | BR-1 | Guest preferences (high floor, late checkout) |
| `created_at` | DATETIME | Core | When booking was made |
| `created_by` | INT | Core | Staff who created booking |

**Status Values Rationale:**
- `Pending` - BR-1: Initial state after booking
- `Confirmed` - BR-1: Payment received or guaranteed
- `CheckedIn` - BR-2: Guest arrived
- `CheckedOut` - BR-2: Guest departed
- `Cancelled` - BR-3: Guest cancelled
- `NoShow` - BR-3: Guest didn't arrive

---

### 7.5 PAYMENTS Table

**Purpose:** Financial transaction records (BR-4, BR-5)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `payment_id` | INT PK | Core | Unique transaction identifier |
| `reservation_id` | INT FK | BR-4: "Update reservation balances" | Links payment to booking |
| `amount` | DECIMAL | BR-4: "Record payments" | Transaction amount |
| `payment_method` | NVARCHAR(20) | BR-4: "Multiple payment methods" | Cash, Credit, Debit, Transfer |
| `payment_date` | DATETIME | BR-4, BR-7 | When transaction occurred - for reporting |
| `transaction_reference` | NVARCHAR(100) | BR-4 | External reference (credit card auth, bank ref) |
| `status` | NVARCHAR(20) | BR-4 | Completed, Pending, Failed, Refunded |
| `processed_by` | INT FK | BR-4 | Staff who processed payment |
| `notes` | NVARCHAR(500) | BR-4 | Additional transaction details |

---

### 7.6 SERVICES Table

**Purpose:** Available hotel services catalog (BR-9)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `service_id` | INT PK | Core | Unique identifier |
| `service_name` | NVARCHAR(100) | BR-9: "View available services" | Display name (Room Service, Spa) |
| `category_id` | INT FK | BR-11: "Category-level analysis" | Links to SERVICE_CATEGORIES |
| `price` | DECIMAL | BR-9: "View prices" | Service charge amount |
| `description` | NVARCHAR(500) | BR-9 | Service details for guests |
| `is_active` | BIT | Core | Whether service is currently offered |

---

### 7.7 SERVICES_USED Table

**Purpose:** Track service consumption per reservation (BR-5, BR-9)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `usage_id` | INT PK | Core | Unique identifier |
| `reservation_id` | INT FK | BR-9: "Add services to reservations" | Links to guest's booking |
| `service_id` | INT FK | BR-9: "Track service usage" | Which service was used |
| `quantity` | INT | BR-5: "Itemize charges" | Number of units (e.g., 2 spa sessions) |
| `unit_price` | DECIMAL | BR-5: "Include services in invoice" | Price at time of use (may differ from current) |
| `total_price` | DECIMAL | BR-5 | quantity × unit_price |
| `service_date` | DATETIME | BR-9, BR-11 | When service was consumed |
| `notes` | NVARCHAR(500) | BR-9 | Special instructions or details |

---

### 7.8 EMPLOYEES Table

**Purpose:** Staff records (BR-13, BR-15)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `employee_id` | INT PK | Core | Unique identifier |
| `first_name` | NVARCHAR(50) | BR-15 | Staff identification |
| `last_name` | NVARCHAR(50) | BR-15 | Full name for records |
| `email` | NVARCHAR(100) | BR-15, BR-16 | Contact and login identifier |
| `phone` | NVARCHAR(20) | BR-15 | Emergency contact |
| `department_id` | INT FK | BR-13: "Check staff availability" | Which department (Housekeeping, Maintenance) |
| `position` | NVARCHAR(50) | BR-13, BR-15 | Job title for assignment logic |
| `hire_date` | DATE | BR-15 | Employment start date |
| `hourly_rate` | DECIMAL | BR-15: "Generate schedules" | For payroll calculations |
| `is_active` | BIT | BR-13: "Available staff" | Currently employed and available |

---

### 7.9 EMPLOYEE_SHIFTS Table

**Purpose:** Work schedule records (BR-15)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `shift_id` | INT PK | Core | Unique identifier |
| `employee_id` | INT FK | BR-15: "Track attendance" | Which employee |
| `shift_date` | DATE | BR-15: "Weekly schedules" | Work date |
| `start_time` | TIME | BR-15: "Generate schedules" | Shift start |
| `end_time` | TIME | BR-15 | Shift end |
| `actual_start` | TIME | BR-15: "Track attendance" | When employee actually clocked in |
| `actual_end` | TIME | BR-15 | When employee actually clocked out |
| `status` | NVARCHAR(20) | BR-15 | Scheduled, Completed, Absent, etc. |

---

### 7.10 MAINTENANCE_REQUESTS Table

**Purpose:** Room issues and repair tracking (BR-12, BR-13)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `request_id` | INT PK | Core | Unique identifier |
| `room_id` | INT FK | BR-12: "Track room issues" | Which room has the problem |
| `issue_type` | NVARCHAR(50) | BR-12 | Category (Plumbing, Electrical, HVAC) |
| `description` | NVARCHAR(500) | BR-12: "Report issues" | Detailed problem description |
| `priority` | NVARCHAR(20) | BR-12: "Create with priority" | Critical, High, Medium, Low |
| `status` | NVARCHAR(20) | BR-12: "Track status" | Pending, Assigned, InProgress, Completed |
| `assigned_to` | INT FK | BR-13: "Assign tasks" | Employee responsible |
| `reported_by` | INT FK | BR-12 | Who reported the issue |
| `created_at` | DATETIME | BR-12: "Measure response time" | When issue was reported |
| `assigned_at` | DATETIME | BR-12 | When task was assigned |
| `completed_at` | DATETIME | BR-12: "Measure resolution time" | When task was finished |
| `resolution_notes` | NVARCHAR(500) | BR-12 | What was done to fix it |

---

### 7.11 ROOM_STATUS_HISTORY Table

**Purpose:** Audit trail for room status changes (BR-14)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `history_id` | INT PK | Core | Unique identifier |
| `room_id` | INT FK | BR-14: "Track status history" | Which room |
| `old_status` | NVARCHAR(20) | BR-14: "Log changes" | Status before change |
| `new_status` | NVARCHAR(20) | BR-14 | Status after change |
| `changed_at` | DATETIME | BR-14: "Calculate turnaround time" | When change occurred |
| `changed_by` | INT FK | BR-14 | Who made the change (or trigger) |

---

### 7.12 NOTIFICATIONS Table

**Purpose:** System alerts and notifications (BR-12)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `notification_id` | INT PK | Core | Unique identifier |
| `recipient_id` | INT FK | BR-12: "Alert for high-priority" | Who should receive notification |
| `type` | NVARCHAR(50) | BR-12 | Category (Maintenance, Payment, etc.) |
| `title` | NVARCHAR(100) | BR-12 | Brief subject |
| `message` | NVARCHAR(1000) | BR-12 | Full notification content |
| `is_read` | BIT | Core | Has recipient seen it |
| `created_at` | DATETIME | Core | When notification was created |
| `reference_id` | INT | Core | Related record ID (e.g., maintenance_request_id) |

---

### 7.13 AUDIT_LOGS Table

**Purpose:** System-wide audit trail (BR-16)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `log_id` | INT PK | Core | Unique identifier |
| `table_name` | NVARCHAR(50) | BR-16: "Audit trail" | Which table was modified |
| `operation` | NVARCHAR(20) | BR-16 | INSERT, UPDATE, DELETE |
| `record_id` | INT | BR-16 | ID of affected record |
| `old_values` | NVARCHAR(MAX) | BR-16 | Previous data (for UPDATE/DELETE) |
| `new_values` | NVARCHAR(MAX) | BR-16 | New data (for INSERT/UPDATE) |
| `changed_by` | NVARCHAR(50) | BR-16 | User who made change |
| `changed_at` | DATETIME | BR-16 | When change occurred |

---

### 7.14 USER_ACCOUNTS Table (Authentication)

**Purpose:** User login credentials and access control (BR-16)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `user_id` | INT PK | Core | Unique identifier |
| `username` | NVARCHAR(50) UNIQUE | BR-16: "Secure login" | Login identifier |
| `password_hash` | NVARCHAR(256) | BR-16: "Hashed passwords" | SHA-256 hash of password+salt |
| `password_salt` | NVARCHAR(128) | BR-16: "Secure login" | Random salt for each user |
| `email` | NVARCHAR(100) | BR-16 | Contact and password recovery |
| `role_id` | INT FK | BR-16: "Role-based access" | Links to ROLES for access level |
| `user_type` | NVARCHAR(20) | BR-16 | Employee or Customer |
| `employee_id` | INT FK | BR-16 | Links to EMPLOYEES if staff |
| `customer_id` | INT FK | BR-16 | Links to CUSTOMERS if guest |
| `is_active` | BIT | BR-16 | Account enabled/disabled |
| `is_locked` | BIT | BR-16: "Account lockout" | Locked after failed attempts |
| `failed_login_attempts` | INT | BR-16: "Lockout after failed attempts" | Counter for security |
| `last_login` | DATETIME | BR-16 | Track last access |

---

### 7.15 ROLES Table (Authentication)

**Purpose:** Access control levels (BR-16)

| Field | Data Type | Requirement Source | Rationale |
|-------|-----------|-------------------|-----------|
| `role_id` | INT PK | Core | Unique identifier |
| `role_name` | NVARCHAR(50) | BR-16: "Role-based access" | Display name (Administrator, Receptionist) |
| `description` | NVARCHAR(500) | BR-16 | Role responsibilities |
| `role_level` | INT | BR-16: "Access levels" | Numeric level (10-100) for hierarchical access |
| `is_active` | BIT | Core | Whether role is in use |

---

## 8. Summary

This document provides complete traceability between:

1. **Business Requirements** (16 requirements in 5 categories)
2. **Database Tables** (16 tables with 150+ fields)
3. **Database Objects** (47+ procedures, views, triggers, functions)
4. **Team Member Responsibilities** (4 members + shared auth module)

Every field in every table exists to support a specific business requirement, ensuring no unnecessary data is stored and all operational needs are met.

