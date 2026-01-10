# User Requirements Document
## Hotel Management System

---

## 1. Introduction

### 1.1 Purpose
This document describes the user requirements for the **Hotel Management System (HMS)** database for a mid-sized hotel (50-200 rooms). Each requirement traces directly to the database tables, fields, and operations that fulfill it.

### 1.2 Stakeholders
| Stakeholder | Role | Primary Needs |
|-------------|------|---------------|
| Hotel Owner/GM | Strategic oversight | Revenue reports, occupancy metrics |
| Front Desk Manager | Guest services | Reservation management, room status |
| Finance Manager | Financial control | Payment tracking, invoices |
| Housekeeping Supervisor | Room readiness | Room status, cleaning schedules |
| Maintenance Manager | Facility upkeep | Work orders, SLA tracking |
| Receptionists | Guest interaction | Bookings, check-in/out |
| Guests | Accommodation | Easy booking, quality service |

---

## 2. Business Requirements

### 2.1 Guest Self-Service (Customer-Facing)

---

### GR-1: Browse Rooms Online

**User Story:** *"As a guest, I want to browse available rooms on the hotel website, see photos and descriptions of each room type, compare prices and amenities, and filter by my travel dates so that I can find the perfect room for my stay."*

**Acceptance Criteria:**
- View all room types with names, descriptions, and amenities
- See base prices for comparison
- Filter rooms by availability for specific dates
- View room features (max occupancy, floor options)
- See which rooms are available vs booked

---

#### Supporting Tables & Fields

**Table: `ROOM_TYPES`** - Room information for guests

| Field | Type | Rationale |
|-------|------|-----------|
| `type_name` | NVARCHAR(50) | Display name for guest browsing (Deluxe, Suite) |
| `description` | NVARCHAR(500) | Marketing description for guest decision |
| `base_price` | DECIMAL(10,2) | Price shown to guests for comparison |
| `max_occupancy` | INT | Helps guests choose appropriate room size |
| `amenities` | NVARCHAR(500) | Features list (WiFi, AC, TV) for guest comparison |

**Table: `ROOMS`** - Availability checking

| Field | Type | Rationale |
|-------|------|-----------|
| `room_id` | INT PK | For availability queries |
| `room_type_id` | INT FK | Links to room type details |
| `floor` | INT | Guest preference filtering |
| `status` | NVARCHAR(20) | Show only 'Available' rooms |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `vw_room_availability` | View | Real-time room availability for website |
| `fn_check_room_availability()` | Function | Check specific room for date range |

---

### GR-2: Online Booking

**User Story:** *"As a guest, I want to book a room directly on the hotel website by selecting my dates and room type, entering my personal details, seeing the total price with any member discounts applied, and receiving a booking confirmation so that I can secure my reservation without calling the hotel."*

**Acceptance Criteria:**
- Select check-in and check-out dates
- Choose from available room types
- Enter guest count (validated against max occupancy)
- See calculated price with nights breakdown
- Apply member discount if logged in
- Enter special requests (high floor, late checkout)
- Receive reservation confirmation with booking ID

---

#### Supporting Tables & Fields

**Table: `RESERVATIONS`** - Guest-created booking

| Field | Type | Rationale |
|-------|------|-----------|
| `reservation_id` | INT PK | Confirmation number for guest reference |
| `customer_id` | INT FK | Links to guest's account |
| `room_id` | INT FK | Selected room |
| `check_in_date` | DATE | Guest-selected arrival |
| `check_out_date` | DATE | Guest-selected departure |
| `number_of_guests` | INT | Guest input, validated against capacity |
| `status` | NVARCHAR(20) | 'Pending' until payment confirmed |
| `total_amount` | DECIMAL(10,2) | Displayed to guest before confirmation |
| `discount_applied` | DECIMAL(5,2) | Member discount shown to guest |
| `special_requests` | NVARCHAR(500) | Guest preferences captured |

**Table: `CUSTOMERS`** - Guest account for discounts

| Field | Type | Rationale |
|-------|------|-----------|
| `membership_tier` | NVARCHAR(20) | Determines discount shown during booking |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_create_reservation` | Procedure | Creates booking from website |
| `fn_calculate_room_price()` | Function | Shows guest total before confirmation |
| `fn_calculate_discount_rate()` | Function | Applies member discount |

---

### GR-3: View My Reservations

**User Story:** *"As a guest, I want to log in to my account and view all my past and upcoming reservations, see the details of each booking (dates, room, total cost), and check the status (confirmed, checked-in, completed) so that I can manage my stays."*

**Acceptance Criteria:**
- List all reservations for logged-in customer
- Show upcoming reservations prominently
- Display booking details: dates, room type, guests, total
- Show current status of each reservation
- View payment status (paid vs outstanding balance)

---

#### Supporting Tables & Fields

**Table: `RESERVATIONS`** - Guest booking history

| Field | Type | Rationale |
|-------|------|-----------|
| `reservation_id` | INT PK | Reference number for guest |
| `customer_id` | INT FK | Filter by logged-in guest |
| `check_in_date` | DATE | Show in reservation list |
| `check_out_date` | DATE | Duration display |
| `status` | NVARCHAR(20) | Current booking status |
| `total_amount` | DECIMAL(10,2) | Total charged |
| `paid_amount` | DECIMAL(10,2) | For balance calculation |

**Table: `ROOMS`** - Room details

| Field | Type | Rationale |
|-------|------|-----------|
| `room_number` | NVARCHAR(10) | Show assigned room to guest |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `vw_customer_history` | View | Complete guest profile with bookings |

---

### GR-4: Check Loyalty Status

**User Story:** *"As a guest, I want to view my loyalty program status including my current tier (Bronze, Silver, Gold, Platinum), my accumulated points balance, how much more I need to spend to reach the next tier, and my discount rate so that I can track my membership benefits."*

**Acceptance Criteria:**
- Display current membership tier with benefits
- Show points balance
- Calculate spending needed for next tier
- Display current discount percentage
- Show lifetime spending total

---

#### Supporting Tables & Fields

**Table: `CUSTOMERS`** - Loyalty data

| Field | Type | Rationale |
|-------|------|-----------|
| `membership_tier` | NVARCHAR(20) | Current tier displayed to guest |
| `loyalty_points` | INT | Points balance shown to guest |
| `total_spending` | DECIMAL(12,2) | For next-tier calculation |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `fn_get_customer_tier()` | Function | Returns current tier |
| `fn_get_customer_discount_rate()` | Function | Returns discount percentage |
| `fn_get_customer_statistics()` | Function | Complete loyalty analytics |

---

### GR-5: Submit Review

**User Story:** *"As a guest who has completed a stay, I want to rate my experience (1-5 stars) and leave a written review so that the hotel can improve and other guests can make informed decisions."*

**Acceptance Criteria:**
- Only allow reviews for completed stays (status = 'CheckedOut')
- Submit star rating (1-5)
- Write optional text review
- View my submitted reviews

---

#### Supporting Tables & Fields

**Table: `REVIEWS`** - Guest feedback

| Field | Type | Rationale |
|-------|------|-----------|
| `review_id` | INT PK | Unique identifier |
| `reservation_id` | INT FK | Links to completed stay |
| `customer_id` | INT FK | Who wrote the review |
| `rating` | INT | 1-5 star rating |
| `comment` | NVARCHAR(1000) | Written feedback |
| `created_at` | DATETIME | When review was submitted |
| `is_published` | BIT | Whether publicly visible |

---

### 2.2 Staff Operations

### BR-1: Room Booking

**User Story:** *"As a receptionist, I need to check room availability for specific dates, see room details and pricing, validate guest count against room capacity, apply member discounts, and create reservations quickly so that guests can book their stay without delays."*

**Acceptance Criteria:**
- View all rooms with their types, floor, status, and availability for any date range
- See base price, maximum occupancy, and amenities for each room type
- Calculate accurate pricing based on room type, duration, and seasonal rates
- Validate that number of guests does not exceed room's maximum occupancy
- Automatically apply member discount based on customer's loyalty tier
- Record special requests from guests (late check-out, high floor, etc.)
- Track who created the reservation and when

---

#### Supporting Tables & Fields

**Table: `ROOM_TYPES`** - Defines room categories

| Field | Type | Rationale |
|-------|------|-----------|
| `room_type_id` | INT PK | Unique identifier for each room category |
| `type_name` | NVARCHAR(50) | Display name (Standard, Deluxe, Suite) for guest selection |
| `description` | NVARCHAR(500) | Marketing description shown to guests during booking |
| `base_price` | DECIMAL(10,2) | Starting price for nightly rate calculation |
| `max_occupancy` | INT | Maximum guests allowed - enforced during reservation |
| `amenities` | NVARCHAR(500) | Features list (WiFi, AC, TV) for guest comparison |

**Table: `ROOMS`** - Individual room inventory

| Field | Type | Rationale |
|-------|------|-----------|
| `room_id` | INT PK | Unique identifier for each physical room |
| `room_number` | NVARCHAR(10) | Physical room number (e.g., "301") for guest reference |
| `room_type_id` | INT FK | Links to ROOM_TYPES for pricing and capacity rules |
| `floor` | INT | Guest preference (high/low floor) and housekeeping routing |
| `status` | NVARCHAR(20) | Current state: Available, Occupied, Reserved, Maintenance |
| `is_active` | BIT | Whether room is in service (vs closed for renovation) |

**Table: `RESERVATIONS`** - Booking records

| Field | Type | Rationale |
|-------|------|-----------|
| `reservation_id` | INT PK | Unique booking identifier for tracking |
| `customer_id` | INT FK | Links booking to guest for loyalty and history |
| `room_id` | INT FK | Specific room assigned to this booking |
| `check_in_date` | DATE | Arrival date for availability checking |
| `check_out_date` | DATE | Departure date for pricing calculation (nights = checkout - checkin) |
| `number_of_guests` | INT | Guest count - validated against max_occupancy |
| `status` | NVARCHAR(20) | Lifecycle: Pending, Confirmed, CheckedIn, CheckedOut, Cancelled |
| `total_amount` | DECIMAL(10,2) | Calculated total: base_price × nights × seasonal factor |
| `discount_applied` | DECIMAL(5,2) | Member discount percentage based on loyalty tier |
| `special_requests` | NVARCHAR(500) | Guest preferences (late checkout, extra pillows) |
| `created_at` | DATETIME | When booking was made - for reporting |
| `created_by` | INT FK | Staff member who created - for accountability |

**Table: `CUSTOMERS`** - Guest information (for discount lookup)

| Field | Type | Rationale |
|-------|------|-----------|
| `customer_id` | INT PK | Links to reservation for loyalty benefits |
| `membership_tier` | NVARCHAR(20) | Bronze/Silver/Gold/Platinum - determines discount rate |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `fn_check_room_availability()` | Function | Returns 1 if room available for date range |
| `fn_calculate_room_price()` | Function | Calculates price with seasonal adjustments |
| `fn_calculate_discount_rate()` | Function | Returns discount % based on membership tier |
| `vw_room_availability` | View | Real-time room status and availability |
| `sp_create_reservation` | Procedure | Validates and creates booking with all calculations |
| `trg_reservation_audit` | Trigger | Logs all reservation changes to AUDIT_LOGS |

---

### BR-2: Check-In / Check-Out

**User Story:** *"As a receptionist, I need to view today's expected arrivals, quickly check in guests and have the room status automatically update to 'Occupied', process check-outs with automatic room status change to 'NeedsCleaning', and track daily occupancy metrics so that housekeeping knows which rooms need attention."*

**Acceptance Criteria:**
- View list of reservations with check-in date = today
- Update reservation status from 'Confirmed' to 'CheckedIn'
- Room status automatically changes to 'Occupied' on check-in
- Update reservation status to 'CheckedOut' on departure
- Room status automatically changes to 'NeedsCleaning' on check-out
- Calculate and display daily occupancy rate
- Track RevPAR (Revenue Per Available Room) metrics

---

#### Supporting Tables & Fields

**Table: `RESERVATIONS`** - Status tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `status` | NVARCHAR(20) | Tracks lifecycle: CheckedIn, CheckedOut states |
| `check_in_date` | DATE | Filter for today's arrivals |

**Table: `ROOMS`** - Status management

| Field | Type | Rationale |
|-------|------|-----------|
| `status` | NVARCHAR(20) | Updates to 'Occupied' on check-in, 'NeedsCleaning' on check-out |

**Table: `ROOM_STATUS_HISTORY`** - Audit trail for status changes

| Field | Type | Rationale |
|-------|------|-----------|
| `history_id` | INT PK | Unique identifier |
| `room_id` | INT FK | Which room changed status |
| `old_status` | NVARCHAR(20) | Previous status (e.g., Available) |
| `new_status` | NVARCHAR(20) | New status (e.g., Occupied) |
| `changed_at` | DATETIME | When change occurred - for turnaround time calculation |
| `changed_by` | INT FK | Who/what triggered change (user or trigger) |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_process_daily_checkins` | **CURSOR** | Batch processes all expected arrivals for today |
| `trg_reservation_status_change` | Trigger | Auto-updates room status when reservation changes |
| `vw_occupancy_statistics` | View | Daily occupancy rates and RevPAR metrics |

---

### BR-3: Cancellation & No-Shows

**User Story:** *"As a manager, I need to process cancellations with tiered refund policies based on how far in advance the guest cancels, release cancelled rooms back to inventory immediately, automatically identify and process no-show guests after their check-in date has passed, and apply no-show penalties so that revenue is protected."*

**Acceptance Criteria:**
- Cancel reservations with refund calculation: 100% if >7 days, 50% if 3-7 days, 0% if <3 days
- Update room status to 'Available' when booking is cancelled
- Automatically detect reservations where check_in_date < today AND status = 'Confirmed'
- Mark detected reservations as 'NoShow' status
- Record refund amount for cancelled bookings
- Track paid_amount for penalty calculations

---

#### Supporting Tables & Fields

**Table: `RESERVATIONS`** - Cancellation tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `status` | NVARCHAR(20) | 'Cancelled' or 'NoShow' states |
| `check_in_date` | DATE | Compare to current date for no-show detection |
| `total_amount` | DECIMAL(10,2) | Base for refund/penalty calculation |
| `paid_amount` | DECIMAL(10,2) | Amount already paid - for refund processing |

**Table: `PAYMENTS`** - Refund tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `status` | NVARCHAR(20) | 'Refunded' status for cancelled bookings |
| `amount` | DECIMAL(10,2) | Negative amount for refunds |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_cancel_reservation` | Procedure | Calculates tiered refund, updates status |
| `sp_process_noshow_reservations` | **CURSOR** | Batch finds and processes all no-shows |
| `trg_reservation_status_change` | Trigger | Releases room to 'Available' on cancellation |

---

### BR-4: Payment Processing

**User Story:** *"As a cashier, I need to record payments in multiple formats (cash, credit, debit, bank transfer), update the reservation's paid balance after each payment, automatically award loyalty points based on payment amount and member tier, generate payment receipts with transaction references, and track all payments for audit purposes so that finances are accurate."*

**Acceptance Criteria:**
- Accept Cash, Credit, Debit, and Bank Transfer payments
- Update reservation's `paid_amount` after each payment
- Calculate loyalty points: amount × tier_multiplier (1x Bronze, 1.5x Silver, 2x Gold, 3x Platinum)
- Add earned points to customer's `loyalty_points` balance
- Update customer's `total_spending` for tier calculations
- Store transaction reference for credit/debit/transfer payments
- Log all payments to audit system

---

#### Supporting Tables & Fields

**Table: `PAYMENTS`** - Transaction records

| Field | Type | Rationale |
|-------|------|-----------|
| `payment_id` | INT PK | Unique transaction identifier |
| `reservation_id` | INT FK | Links payment to booking |
| `amount` | DECIMAL(10,2) | Payment amount |
| `payment_method` | NVARCHAR(20) | Cash, Credit, Debit, Transfer |
| `payment_date` | DATETIME | When payment occurred - for daily reports |
| `transaction_reference` | NVARCHAR(100) | Card authorization or bank reference number |
| `status` | NVARCHAR(20) | Completed, Pending, Failed, Refunded |
| `processed_by` | INT FK | Staff member for accountability |
| `notes` | NVARCHAR(500) | Additional details (split payment, etc.) |

**Table: `RESERVATIONS`** - Balance tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `paid_amount` | DECIMAL(10,2) | Running total of payments received |
| `total_amount` | DECIMAL(10,2) | Total due - for balance calculation |

**Table: `CUSTOMERS`** - Loyalty updates

| Field | Type | Rationale |
|-------|------|-----------|
| `loyalty_points` | INT | Accumulated points - increased with each payment |
| `total_spending` | DECIMAL(12,2) | Cumulative spend - for tier upgrade calculation |
| `membership_tier` | NVARCHAR(20) | Current tier - determines points multiplier |

**Table: `AUDIT_LOGS`** - Payment audit

| Field | Type | Rationale |
|-------|------|-----------|
| `table_name` | NVARCHAR(50) | 'PAYMENTS' for payment transactions |
| `operation` | NVARCHAR(20) | INSERT, UPDATE |
| `record_id` | INT | payment_id of the transaction |
| `new_values` | NVARCHAR(MAX) | Serialized payment details |
| `changed_by` | NVARCHAR(50) | Who processed the payment |
| `changed_at` | DATETIME | When payment was made |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_process_payment` | Procedure | Records payment, updates balance, awards points |
| `fn_calculate_loyalty_points()` | Function | Points = amount × tier_multiplier |
| `trg_payment_audit` | Trigger | Logs all payments to AUDIT_LOGS |
| `trg_payment_loyalty_update` | Trigger | Auto-upgrades tier when thresholds reached |

---

### BR-5: Invoice Generation

**User Story:** *"As a cashier, I need to generate a detailed invoice that lists each night's room charges with the specific rate applied, itemizes all services consumed (room service, spa, laundry) with quantities and prices, applies the customer's membership discount, adds applicable taxes, and calculates the final total due so that the guest has a complete breakdown of charges."*

**Acceptance Criteria:**
- List each night with nightly rate
- Group and itemize all services from SERVICES_USED
- Show service quantity, unit price, and line total
- Apply membership discount percentage to room charges
- Calculate and add 10% tax
- Show payments already received
- Calculate balance due (total - paid)

---

#### Supporting Tables & Fields

**Table: `SERVICES_USED`** - Consumed services

| Field | Type | Rationale |
|-------|------|-----------|
| `usage_id` | INT PK | Unique identifier |
| `reservation_id` | INT FK | Links to guest's booking for invoice grouping |
| `service_id` | INT FK | Which service was used |
| `quantity` | INT | Number of units (e.g., 2 dinners) |
| `unit_price` | DECIMAL(10,2) | Price at time of use (frozen, not current price) |
| `total_price` | DECIMAL(10,2) | quantity × unit_price for line item |
| `service_date` | DATETIME | When service was consumed |

**Table: `SERVICES`** - Service catalog

| Field | Type | Rationale |
|-------|------|-----------|
| `service_id` | INT PK | Unique identifier |
| `service_name` | NVARCHAR(100) | Display name on invoice (Room Service, Spa) |
| `category_id` | INT FK | Groups services for invoice sections |
| `price` | DECIMAL(10,2) | Current price (unit_price is snapshot at usage time) |

**Table: `SERVICE_CATEGORIES`** - Invoice grouping

| Field | Type | Rationale |
|-------|------|-----------|
| `category_id` | INT PK | Unique identifier |
| `category_name` | NVARCHAR(50) | Section header on invoice (Food & Beverage, Spa) |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `fn_calculate_total_bill()` | Function | Returns itemized bill as table-valued function |
| `sp_generate_invoice` | **CURSOR** | Iterates through charges, builds formatted invoice |

---

### BR-6: Outstanding Payment Tracking

**User Story:** *"As a finance manager, I need to view all reservations with unpaid balances, see how long each balance has been outstanding (aging buckets: current, 30 days, 60 days, 90+ days), identify high-value outstanding accounts, and send automated payment reminders so that receivables are collected promptly."*

**Acceptance Criteria:**
- Show all reservations where paid_amount < total_amount
- Calculate days_outstanding from check_out_date
- Categorize into aging buckets (0-30, 31-60, 61-90, 90+)
- Sort by outstanding balance descending for priority
- Send reminder notifications to customers
- Track reminder history in notifications

---

#### Supporting Tables & Fields

**Table: `RESERVATIONS`** - Balance tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `total_amount` | DECIMAL(10,2) | What is owed |
| `paid_amount` | DECIMAL(10,2) | What has been paid |
| `check_out_date` | DATE | Calculate days outstanding from this date |

**Table: `NOTIFICATIONS`** - Reminder tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `notification_id` | INT PK | Unique identifier |
| `recipient_id` | INT FK | Customer to notify |
| `type` | NVARCHAR(50) | 'PaymentReminder' type |
| `title` | NVARCHAR(100) | "Payment Reminder" |
| `message` | NVARCHAR(1000) | Details of outstanding balance |
| `is_read` | BIT | Whether customer has seen notification |
| `created_at` | DATETIME | When reminder was sent |
| `reference_id` | INT | reservation_id for context |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `vw_outstanding_payments` | View | Lists all unpaid balances with aging analysis |
| `sp_send_payment_reminders` | **CURSOR** | Batch sends reminders for overdue accounts |

---

### BR-7: Financial Reporting

**User Story:** *"As a GM, I need to view daily revenue broken down by room type and payment method, generate monthly revenue summaries comparing this month to previous periods, track payment trends over time, and identify which room types generate the most revenue so that I can make informed business decisions."*

**Acceptance Criteria:**
- Show daily revenue grouped by room_type_name
- Show daily revenue grouped by payment_method
- Calculate monthly totals for comparison
- Calculate average daily rate (ADR) by room type
- Show revenue trend data for charting

---

#### Supporting Tables & Fields

**Table: `PAYMENTS`** - Revenue source

| Field | Type | Rationale |
|-------|------|-----------|
| `amount` | DECIMAL(10,2) | Revenue amount |
| `payment_date` | DATETIME | Group by day/month for reports |
| `payment_method` | NVARCHAR(20) | Breakdown by payment type |

**Table: `RESERVATIONS`** - Room revenue

| Field | Type | Rationale |
|-------|------|-----------|
| `total_amount` | DECIMAL(10,2) | Room revenue |
| `room_id` | INT FK | Links to room_type for grouping |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `vw_daily_revenue_report` | View | Today's revenue by type and method |
| `sp_generate_monthly_revenue_summary` | **CURSOR** | Detailed monthly financial analysis |

---

### BR-8: Customer Registration

**User Story:** *"As a receptionist, I need to register new guests by capturing their personal information (name, contact, government ID), validate that their email and phone are unique in the system, automatically enroll them in the loyalty program at Bronze tier, and award 100 welcome bonus points so that guests are immediately recognized as members."*

**Acceptance Criteria:**
- Capture first_name, last_name, email, phone, id_type, id_number, date_of_birth
- Validate email is not already registered (unique constraint)
- Validate phone is not already registered
- Set membership_tier = 'Bronze' for new customers
- Set loyalty_points = 100 (welcome bonus)
- Set total_spending = 0
- Record registration timestamp

---

#### Supporting Tables & Fields

**Table: `CUSTOMERS`** - Guest master data

| Field | Type | Rationale |
|-------|------|-----------|
| `customer_id` | INT PK | Unique identifier |
| `first_name` | NVARCHAR(50) | Personal salutation |
| `last_name` | NVARCHAR(50) | Legal name for ID matching |
| `email` | NVARCHAR(100) UNIQUE | Primary contact - must be unique per customer |
| `phone` | NVARCHAR(20) | Secondary contact for urgent notifications |
| `id_type` | NVARCHAR(20) | Passport, NationalID, DriverLicense - legal requirement |
| `id_number` | NVARCHAR(50) | Government ID number for verification |
| `date_of_birth` | DATE | Age verification, birthday promotions |
| `membership_tier` | NVARCHAR(20) | Loyalty tier - starts as 'Bronze' |
| `loyalty_points` | INT | Points balance - starts at 100 (welcome bonus) |
| `total_spending` | DECIMAL(12,2) | Cumulative spend - starts at 0 |
| `created_at` | DATETIME | Registration timestamp |
| `is_active` | BIT | Account status (soft delete capability) |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_register_customer` | Procedure | Validates and creates customer with welcome bonus |
| `vw_customer_history` | View | Complete customer profile with stay history |

---

### BR-9: Service Management

**User Story:** *"As F&B/Spa staff, I need to view available services with their prices and descriptions, add service charges to a guest's room bill (linked to their reservation), record the quantity and date of service usage, and have the system alert managers when high-value services (over $200) are added so that VIP service can be ensured."*

**Acceptance Criteria:**
- List all active services with names, prices, categories
- Add service to reservation with quantity
- Store unit_price at time of usage (price may change later)
- Calculate total_price = quantity × unit_price
- Create notification if total_price > $200
- Track which staff member added the service

---

#### Supporting Tables & Fields

**Table: `SERVICES`** - Service catalog

| Field | Type | Rationale |
|-------|------|-----------|
| `service_id` | INT PK | Unique identifier |
| `service_name` | NVARCHAR(100) | Display name for staff selection |
| `category_id` | INT FK | Groups by type (F&B, Spa, Laundry) |
| `price` | DECIMAL(10,2) | Current price |
| `description` | NVARCHAR(500) | Service details |
| `is_active` | BIT | Whether currently offered |

**Table: `SERVICES_USED`** - Usage records

| Field | Type | Rationale |
|-------|------|-----------|
| `usage_id` | INT PK | Unique identifier |
| `reservation_id` | INT FK | Links charge to guest's bill |
| `service_id` | INT FK | Which service |
| `quantity` | INT | How many units |
| `unit_price` | DECIMAL(10,2) | Price snapshot at usage time |
| `total_price` | DECIMAL(10,2) | Line total for billing |
| `service_date` | DATETIME | When consumed |
| `notes` | NVARCHAR(500) | Special instructions |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_add_service_to_reservation` | Procedure | Adds service charge to guest bill |
| `vw_popular_services` | View | Service usage analytics and trends |
| `trg_service_usage_notification` | Trigger | Alerts manager for high-value services (>$200) |

---

### BR-10: Loyalty Program

**User Story:** *"As a manager, I want loyal customers to progress through four membership tiers (Bronze, Silver, Gold, Platinum) based on their total spending at the hotel, automatically receive tier upgrades when spending thresholds are reached ($1000 Silver, $5000 Gold, $15000 Platinum), and enjoy tier-specific discount rates (5% Silver, 10% Gold, 15% Platinum) so that repeat guests are rewarded."*

**Acceptance Criteria:**
- Track total_spending across all reservations and services
- Tier thresholds: $1000 = Silver, $5000 = Gold, $15000 = Platinum
- Discount rates: Bronze 0%, Silver 5%, Gold 10%, Platinum 15%
- Points multiplier: Bronze 1x, Silver 1.5x, Gold 2x, Platinum 3x
- Automatically upgrade tier when threshold reached
- Award bonus points on tier upgrade

---

#### Supporting Tables & Fields

**Table: `CUSTOMERS`** - Loyalty tracking

| Field | Type | Rationale |
|-------|------|-----------|
| `membership_tier` | NVARCHAR(20) | Current tier level |
| `loyalty_points` | INT | Redeemable points balance |
| `total_spending` | DECIMAL(12,2) | Cumulative spend for tier calculation |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `fn_get_customer_tier()` | Function | Calculates tier from spending |
| `fn_get_customer_discount_rate()` | Function | Returns discount % for tier |
| `fn_get_customer_statistics()` | Function | Returns complete customer analytics |
| `sp_process_loyalty_tier_upgrades` | **CURSOR** | Batch upgrades all eligible customers |
| `trg_customer_tier_upgrade` | Trigger | Auto-upgrade on spending threshold |

---

### BR-11: Service Analytics

**User Story:** *"As a manager, I need to analyze which services are most popular (by usage count), which generate the most revenue, identify top-spending customers by service category, and track service trends over time so that I can optimize service offerings."*

**Acceptance Criteria:**
- Rank services by usage count
- Rank services by total revenue
- Group analytics by service category
- Identify top 10 service spenders
- Show monthly service trends

---

#### Supporting Tables & Fields

**Table: `SERVICES_USED`** - Usage data

| Field | Type | Rationale |
|-------|------|-----------|
| `service_id` | INT FK | Group by service for popularity |
| `total_price` | DECIMAL(10,2) | Sum for revenue analysis |
| `service_date` | DATETIME | Trend analysis over time |

**Table: `SERVICE_CATEGORIES`** - Grouping

| Field | Type | Rationale |
|-------|------|-----------|
| `category_id` | INT PK | Group services by category |
| `category_name` | NVARCHAR(50) | Display name for reports |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `vw_popular_services` | View | Ranked service analytics |
| `sp_generate_service_usage_report` | **CURSOR** | Detailed usage analysis by category |

---

### BR-12: Maintenance Request Management

**User Story:** *"As housekeeping staff, I need to report room issues by specifying issue type (Plumbing, Electrical, HVAC, Furniture), set priority level (Critical, High, Medium, Low), have the system automatically alert maintenance managers for high-priority issues, track request status (Pending, Assigned, InProgress, Completed), and record resolution details so that room issues are fixed promptly."*

**Acceptance Criteria:**
- Create requests with room_id, issue_type, description, priority
- Set status = 'Pending' initially
- Create notification for Critical/High priority requests
- Assign to maintenance staff (updates assigned_to, assigned_at)
- Track progress through status changes
- Record completed_at and resolution_notes on completion
- Calculate response time (assigned_at - created_at)
- Calculate resolution time (completed_at - created_at)

---

#### Supporting Tables & Fields

**Table: `MAINTENANCE_REQUESTS`** - Work orders

| Field | Type | Rationale |
|-------|------|-----------|
| `request_id` | INT PK | Unique identifier |
| `room_id` | INT FK | Which room has the issue |
| `issue_type` | NVARCHAR(50) | Category: Plumbing, Electrical, HVAC, Furniture |
| `description` | NVARCHAR(500) | Detailed problem description |
| `priority` | NVARCHAR(20) | Critical, High, Medium, Low - determines SLA |
| `status` | NVARCHAR(20) | Pending, Assigned, InProgress, Completed |
| `assigned_to` | INT FK | Maintenance employee responsible |
| `reported_by` | INT FK | Staff who reported issue |
| `created_at` | DATETIME | When issue was reported - SLA start |
| `assigned_at` | DATETIME | When task was assigned |
| `completed_at` | DATETIME | When task finished - for resolution time |
| `resolution_notes` | NVARCHAR(500) | What was done to fix it |

**Table: `NOTIFICATIONS`** - Priority alerts

| Field | Type | Rationale |
|-------|------|-----------|
| `type` | NVARCHAR(50) | 'MaintenanceAlert' for high-priority |
| `recipient_id` | INT FK | Maintenance manager to alert |
| `reference_id` | INT | request_id for context |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_create_maintenance_request` | Procedure | Creates request, optionally assigns |
| `sp_complete_maintenance` | Procedure | Marks complete, records resolution |
| `trg_high_priority_maintenance` | Trigger | Alerts manager for Critical/High issues |
| `vw_maintenance_dashboard` | View | All requests with SLA status |

---

### BR-13: Staff Task Assignment

**User Story:** *"As a maintenance manager, I need to see which staff members are available in the maintenance department, check their current workload (pending tasks assigned), automatically distribute unassigned tasks to available staff with the lowest workload, and track assignment history so that work is balanced fairly."*

**Acceptance Criteria:**
- List maintenance staff with is_active = 1
- Count pending tasks per employee
- Assign task to employee with lowest pending count
- Update request's assigned_to and assigned_at
- Update status to 'Assigned'

---

#### Supporting Tables & Fields

**Table: `EMPLOYEES`** - Staff roster

| Field | Type | Rationale |
|-------|------|-----------|
| `employee_id` | INT PK | Unique identifier |
| `first_name` | NVARCHAR(50) | For assignment display |
| `last_name` | NVARCHAR(50) | Full name identification |
| `department_id` | INT FK | Filter by Maintenance department |
| `position` | NVARCHAR(50) | Job title |
| `is_active` | BIT | Only assign to active employees |

**Table: `DEPARTMENTS`** - Department lookup

| Field | Type | Rationale |
|-------|------|-----------|
| `department_id` | INT PK | Unique identifier |
| `department_name` | NVARCHAR(50) | 'Maintenance', 'Housekeeping', etc. |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `fn_get_available_staff()` | Function | Count available staff by department |
| `sp_auto_assign_maintenance_tasks` | **CURSOR** | Distributes tasks by workload |

---

### BR-14: Room Status Tracking

**User Story:** *"As a housekeeping supervisor, I need to see when rooms change status (Available, Occupied, NeedsCleaning, Maintenance), track the history of all status changes with timestamps, and calculate room turnaround time (time from 'NeedsCleaning' to 'Available') so that cleaning efficiency can be measured."*

**Acceptance Criteria:**
- Log every room status change automatically
- Record old_status, new_status, changed_at, changed_by
- Calculate turnaround = time from NeedsCleaning to Available
- Provide average turnaround metrics per floor/overall

---

#### Supporting Tables & Fields

**Table: `ROOM_STATUS_HISTORY`** - Change log

| Field | Type | Rationale |
|-------|------|-----------|
| `history_id` | INT PK | Unique identifier |
| `room_id` | INT FK | Which room changed |
| `old_status` | NVARCHAR(20) | Status before change |
| `new_status` | NVARCHAR(20) | Status after change |
| `changed_at` | DATETIME | Timestamp - for turnaround calculation |
| `changed_by` | INT FK | User or trigger that made change |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `trg_room_status_history` | Trigger | Logs all status changes automatically |
| `fn_calculate_room_turnaround_time()` | Function | Measures cleaning efficiency |

---

### BR-15: Employee Scheduling

**User Story:** *"As an HR manager, I need to generate weekly shift schedules for all departments, track employee attendance (actual vs scheduled times), view employee performance metrics (tasks completed, hours worked), and ensure fair distribution of shifts across staff so that operations are properly staffed."*

**Acceptance Criteria:**
- Create shift records with employee_id, shift_date, start_time, end_time
- Track actual_start and actual_end for attendance
- Calculate scheduled hours vs actual hours
- Count tasks completed per employee
- Balance shift distribution across employees

---

#### Supporting Tables & Fields

**Table: `EMPLOYEE_SHIFTS`** - Schedule records

| Field | Type | Rationale |
|-------|------|-----------|
| `shift_id` | INT PK | Unique identifier |
| `employee_id` | INT FK | Which employee |
| `shift_date` | DATE | Work date |
| `start_time` | TIME | Scheduled start |
| `end_time` | TIME | Scheduled end |
| `actual_start` | TIME | Clock-in time |
| `actual_end` | TIME | Clock-out time |
| `status` | NVARCHAR(20) | Scheduled, Completed, Absent |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_generate_employee_shift_schedule` | **CURSOR** | Creates weekly schedules |
| `vw_employee_performance` | View | Tasks completed, attendance metrics |
| `fn_get_maintenance_statistics()` | Function | Performance analytics |

---

### BR-16: User Authentication

**User Story:** *"As a hotel employee, I need to log in securely with a username and password, have my password stored in a hashed format for security, have my account locked after 5 failed login attempts, and only access system functions appropriate for my role (receptionist, cashier, manager, etc.) so that the system is secure."*

**Acceptance Criteria:**
- Login with username and password
- Store password as SHA-256 hash with unique salt
- Track failed_login_attempts counter
- Lock account when attempts >= 5
- Return role_level on successful login
- Check role_level >= required_level for operations

---

#### Supporting Tables & Fields

**Table: `ROLES`** - Access levels

| Field | Type | Rationale |
|-------|------|-----------|
| `role_id` | INT PK | Unique identifier |
| `role_name` | NVARCHAR(50) | Display name (Administrator, Receptionist) |
| `description` | NVARCHAR(500) | Role responsibilities |
| `role_level` | INT | Access level (10-100): higher = more access |
| `is_active` | BIT | Whether role is in use |

**Table: `USER_ACCOUNTS`** - Credentials

| Field | Type | Rationale |
|-------|------|-----------|
| `user_id` | INT PK | Unique identifier |
| `username` | NVARCHAR(50) UNIQUE | Login identifier |
| `password_hash` | NVARCHAR(256) | SHA-256 hash of password+salt |
| `password_salt` | NVARCHAR(128) | Random salt for security |
| `email` | NVARCHAR(100) | Contact for password recovery |
| `role_id` | INT FK | Links to ROLES for access level |
| `user_type` | NVARCHAR(20) | 'Employee' or 'Customer' |
| `employee_id` | INT FK | Link to EMPLOYEES if staff |
| `customer_id` | INT FK | Link to CUSTOMERS if guest |
| `is_active` | BIT | Account enabled |
| `is_locked` | BIT | Locked after failed attempts |
| `failed_login_attempts` | INT | Counter for lockout |
| `last_login` | DATETIME | Track last access |

---

#### Database Operations

| Operation | Type | Purpose |
|-----------|------|---------|
| `sp_create_user_account` | Procedure | Creates user with hashed password |
| `sp_user_login` | Procedure | Validates credentials, returns role |
| `sp_change_password` | Procedure | Updates password securely |
| `sp_change_user_role` | Procedure | Changes user's role (manager+) |
| `sp_unlock_user` | Procedure | Unlocks locked account |
| `fn_hash_password()` | Function | SHA-256 hashing with salt |
| `fn_user_has_role()` | Function | Checks if user has specific role |
| `fn_user_can_access()` | Function | Checks minimum access level |
| `fn_get_user_role_level()` | Function | Gets user's role level |

---

## 3. Summary

### Team Member Responsibilities

| Member | Requirements | Objects |
|--------|--------------|---------|
| **Phuc** | BR-1, BR-2, BR-3 | 2 procedures, 2 views, 2 triggers, 3 functions, 2 cursors |
| **Khanh** | BR-4, BR-5, BR-6, BR-7 | 2 procedures, 2 views, 2 triggers, 3 functions, 2 cursors |
| **Ninh** | BR-8, BR-9, BR-10, BR-11 | 2 procedures, 2 views, 2 triggers, 3 functions, 2 cursors |
| **Tung** | BR-12, BR-13, BR-14, BR-15 | 2 procedures, 2 views, 2 triggers, 3 functions, 2 cursors |
| **Shared** | BR-16 | 5 procedures, 4 functions |

### Database Totals

| Item | Count |
|------|-------|
| Business Requirements | 16 |
| Core Tables | 14 |
| Auth Tables | 2 |
| Total Tables | 16 |
| Stored Procedures | 13 |
| Cursor Procedures | 8 |
| Views | 8 |
| Triggers | 8 |
| Functions | 16 |

Every field in every table exists to support a specific user requirement. This document provides complete traceability from user stories to database implementation.
