-- =============================================
-- HOTEL MANAGEMENT SYSTEM - TABLE DEFINITIONS
-- SQL Server Implementation
-- =============================================

USE HotelManagement;
GO

-- =============================================
-- LOOKUP TABLES (No Foreign Keys)
-- =============================================

-- Departments Table
CREATE TABLE DEPARTMENTS (
    department_id INT IDENTITY(1,1) PRIMARY KEY,
    department_name NVARCHAR(100) NOT NULL UNIQUE,
    description NVARCHAR(500),
    created_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1
);
GO

-- Service Categories Table
CREATE TABLE SERVICE_CATEGORIES (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name NVARCHAR(100) NOT NULL UNIQUE,
    description NVARCHAR(500),
    created_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1
);
GO

-- Room Types Table
CREATE TABLE ROOM_TYPES (
    type_id INT IDENTITY(1,1) PRIMARY KEY,
    type_name NVARCHAR(50) NOT NULL UNIQUE,
    description NVARCHAR(500),
    base_price DECIMAL(10, 2) NOT NULL CHECK (base_price > 0),
    capacity INT NOT NULL CHECK (capacity > 0),
    amenities NVARCHAR(1000),
    created_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1
);
GO

-- =============================================
-- CORE TABLES
-- =============================================

-- Customers Table
CREATE TABLE CUSTOMERS (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    phone NVARCHAR(20),
    address NVARCHAR(500),
    id_number NVARCHAR(50),
    id_type NVARCHAR(50) CHECK (id_type IN ('Passport', 'ID Card', 'Driver License')),
    date_of_birth DATE,
    nationality NVARCHAR(50),
    loyalty_points INT DEFAULT 0 CHECK (loyalty_points >= 0),
    membership_tier NVARCHAR(20) DEFAULT 'Bronze' CHECK (membership_tier IN ('Bronze', 'Silver', 'Gold', 'Platinum')),
    total_spending DECIMAL(15, 2) DEFAULT 0,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1
);
GO

-- Employees Table
CREATE TABLE EMPLOYEES (
    employee_id INT IDENTITY(1,1) PRIMARY KEY,
    department_id INT NOT NULL,
    first_name NVARCHAR(50) NOT NULL,
    last_name NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    phone NVARCHAR(20),
    address NVARCHAR(500),
    position NVARCHAR(100) NOT NULL,
    salary DECIMAL(10, 2) CHECK (salary >= 0),
    hire_date DATE NOT NULL DEFAULT GETDATE(),
    birth_date DATE,
    is_available BIT DEFAULT 1,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1,
    CONSTRAINT FK_Employees_Department FOREIGN KEY (department_id) 
        REFERENCES DEPARTMENTS(department_id)
);
GO

-- Rooms Table
CREATE TABLE ROOMS (
    room_id INT IDENTITY(1,1) PRIMARY KEY,
    room_number NVARCHAR(10) NOT NULL UNIQUE,
    type_id INT NOT NULL,
    floor INT NOT NULL,
    status NVARCHAR(20) DEFAULT 'Available' 
        CHECK (status IN ('Available', 'Occupied', 'Maintenance', 'Cleaning', 'Reserved')),
    notes NVARCHAR(500),
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1,
    CONSTRAINT FK_Rooms_Type FOREIGN KEY (type_id) 
        REFERENCES ROOM_TYPES(type_id)
);
GO

-- Services Table
CREATE TABLE SERVICES (
    service_id INT IDENTITY(1,1) PRIMARY KEY,
    category_id INT NOT NULL,
    service_name NVARCHAR(100) NOT NULL,
    description NVARCHAR(500),
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    duration_minutes INT,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    is_active BIT DEFAULT 1,
    CONSTRAINT FK_Services_Category FOREIGN KEY (category_id) 
        REFERENCES SERVICE_CATEGORIES(category_id)
);
GO

-- =============================================
-- TRANSACTIONAL TABLES
-- =============================================

-- Reservations Table
CREATE TABLE RESERVATIONS (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT NOT NULL,
    room_id INT NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    actual_check_in DATETIME,
    actual_check_out DATETIME,
    num_guests INT DEFAULT 1 CHECK (num_guests > 0),
    status NVARCHAR(20) DEFAULT 'Pending' 
        CHECK (status IN ('Pending', 'Confirmed', 'CheckedIn', 'CheckedOut', 'Cancelled', 'NoShow')),
    room_charge DECIMAL(10, 2) DEFAULT 0,
    service_charge DECIMAL(10, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) DEFAULT 0,
    paid_amount DECIMAL(10, 2) DEFAULT 0,
    special_requests NVARCHAR(1000),
    cancellation_reason NVARCHAR(500),
    cancelled_at DATETIME,
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE(),
    created_by INT,
    CONSTRAINT FK_Reservations_Customer FOREIGN KEY (customer_id) 
        REFERENCES CUSTOMERS(customer_id),
    CONSTRAINT FK_Reservations_Room FOREIGN KEY (room_id) 
        REFERENCES ROOMS(room_id),
    CONSTRAINT CHK_Dates CHECK (check_out_date > check_in_date)
);
GO

-- Payments Table
CREATE TABLE PAYMENTS (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    reservation_id INT NOT NULL,
    customer_id INT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_method NVARCHAR(50) NOT NULL 
        CHECK (payment_method IN ('Cash', 'Credit Card', 'Debit Card', 'Bank Transfer', 'Mobile Payment')),
    payment_date DATETIME DEFAULT GETDATE(),
    status NVARCHAR(20) DEFAULT 'Completed' 
        CHECK (status IN ('Pending', 'Completed', 'Failed', 'Refunded', 'Partial')),
    transaction_ref NVARCHAR(100),
    notes NVARCHAR(500),
    processed_by INT,
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Payments_Reservation FOREIGN KEY (reservation_id) 
        REFERENCES RESERVATIONS(reservation_id),
    CONSTRAINT FK_Payments_Customer FOREIGN KEY (customer_id) 
        REFERENCES CUSTOMERS(customer_id)
);
GO

-- Services Used Table
CREATE TABLE SERVICES_USED (
    usage_id INT IDENTITY(1,1) PRIMARY KEY,
    reservation_id INT NOT NULL,
    service_id INT NOT NULL,
    quantity INT DEFAULT 1 CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    used_date DATETIME DEFAULT GETDATE(),
    notes NVARCHAR(500),
    served_by INT,
    status NVARCHAR(20) DEFAULT 'Completed' 
        CHECK (status IN ('Pending', 'InProgress', 'Completed', 'Cancelled')),
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_ServicesUsed_Reservation FOREIGN KEY (reservation_id) 
        REFERENCES RESERVATIONS(reservation_id),
    CONSTRAINT FK_ServicesUsed_Service FOREIGN KEY (service_id) 
        REFERENCES SERVICES(service_id)
);
GO

-- =============================================
-- OPERATIONAL TABLES
-- =============================================

-- Maintenance Requests Table
CREATE TABLE MAINTENANCE_REQUESTS (
    request_id INT IDENTITY(1,1) PRIMARY KEY,
    room_id INT NOT NULL,
    assigned_to INT,
    title NVARCHAR(200) NOT NULL,
    description NVARCHAR(1000),
    priority NVARCHAR(20) DEFAULT 'Medium' 
        CHECK (priority IN ('Low', 'Medium', 'High', 'Critical')),
    status NVARCHAR(20) DEFAULT 'Open' 
        CHECK (status IN ('Open', 'InProgress', 'Completed', 'Cancelled')),
    estimated_cost DECIMAL(10, 2),
    actual_cost DECIMAL(10, 2),
    created_at DATETIME DEFAULT GETDATE(),
    started_at DATETIME,
    completed_at DATETIME,
    created_by INT,
    CONSTRAINT FK_Maintenance_Room FOREIGN KEY (room_id) 
        REFERENCES ROOMS(room_id),
    CONSTRAINT FK_Maintenance_Employee FOREIGN KEY (assigned_to) 
        REFERENCES EMPLOYEES(employee_id)
);
GO

-- Employee Shifts Table
CREATE TABLE EMPLOYEE_SHIFTS (
    shift_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_id INT NOT NULL,
    shift_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    actual_start TIME,
    actual_end TIME,
    status NVARCHAR(20) DEFAULT 'Scheduled' 
        CHECK (status IN ('Scheduled', 'InProgress', 'Completed', 'Absent', 'Cancelled')),
    notes NVARCHAR(500),
    created_at DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Shifts_Employee FOREIGN KEY (employee_id) 
        REFERENCES EMPLOYEES(employee_id)
);
GO

-- =============================================
-- AUDIT & HISTORY TABLES
-- =============================================

-- Room Status History Table
CREATE TABLE ROOM_STATUS_HISTORY (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    room_id INT NOT NULL,
    old_status NVARCHAR(20),
    new_status NVARCHAR(20) NOT NULL,
    changed_at DATETIME DEFAULT GETDATE(),
    changed_by INT,
    reason NVARCHAR(500),
    CONSTRAINT FK_RoomHistory_Room FOREIGN KEY (room_id) 
        REFERENCES ROOMS(room_id)
);
GO

-- Audit Logs Table
CREATE TABLE AUDIT_LOGS (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name NVARCHAR(100) NOT NULL,
    operation NVARCHAR(20) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id INT,
    old_values NVARCHAR(MAX),
    new_values NVARCHAR(MAX),
    changed_by NVARCHAR(100),
    changed_at DATETIME DEFAULT GETDATE(),
    ip_address NVARCHAR(50),
    application NVARCHAR(100)
);
GO

-- Notifications Table (for triggers to insert alerts)
CREATE TABLE NOTIFICATIONS (
    notification_id INT IDENTITY(1,1) PRIMARY KEY,
    notification_type NVARCHAR(50) NOT NULL,
    title NVARCHAR(200) NOT NULL,
    message NVARCHAR(1000),
    related_table NVARCHAR(100),
    related_id INT,
    recipient_type NVARCHAR(50),
    recipient_id INT,
    is_read BIT DEFAULT 0,
    created_at DATETIME DEFAULT GETDATE(),
    read_at DATETIME
);
GO

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Customers Indexes
CREATE INDEX IX_Customers_Email ON CUSTOMERS(email);
CREATE INDEX IX_Customers_MembershipTier ON CUSTOMERS(membership_tier);
CREATE INDEX IX_Customers_LoyaltyPoints ON CUSTOMERS(loyalty_points DESC);

-- Rooms Indexes
CREATE INDEX IX_Rooms_Status ON ROOMS(status);
CREATE INDEX IX_Rooms_TypeId ON ROOMS(type_id);
CREATE INDEX IX_Rooms_Floor ON ROOMS(floor);

-- Reservations Indexes
CREATE INDEX IX_Reservations_CustomerId ON RESERVATIONS(customer_id);
CREATE INDEX IX_Reservations_RoomId ON RESERVATIONS(room_id);
CREATE INDEX IX_Reservations_Status ON RESERVATIONS(status);
CREATE INDEX IX_Reservations_CheckInDate ON RESERVATIONS(check_in_date);
CREATE INDEX IX_Reservations_CheckOutDate ON RESERVATIONS(check_out_date);
CREATE INDEX IX_Reservations_Dates ON RESERVATIONS(check_in_date, check_out_date);

-- Payments Indexes
CREATE INDEX IX_Payments_ReservationId ON PAYMENTS(reservation_id);
CREATE INDEX IX_Payments_CustomerId ON PAYMENTS(customer_id);
CREATE INDEX IX_Payments_Status ON PAYMENTS(status);
CREATE INDEX IX_Payments_Date ON PAYMENTS(payment_date);

-- Services Used Indexes
CREATE INDEX IX_ServicesUsed_ReservationId ON SERVICES_USED(reservation_id);
CREATE INDEX IX_ServicesUsed_ServiceId ON SERVICES_USED(service_id);

-- Maintenance Indexes
CREATE INDEX IX_Maintenance_RoomId ON MAINTENANCE_REQUESTS(room_id);
CREATE INDEX IX_Maintenance_Status ON MAINTENANCE_REQUESTS(status);
CREATE INDEX IX_Maintenance_Priority ON MAINTENANCE_REQUESTS(priority);
CREATE INDEX IX_Maintenance_AssignedTo ON MAINTENANCE_REQUESTS(assigned_to);

-- Employee Shifts Indexes
CREATE INDEX IX_Shifts_EmployeeId ON EMPLOYEE_SHIFTS(employee_id);
CREATE INDEX IX_Shifts_Date ON EMPLOYEE_SHIFTS(shift_date);

-- Audit Logs Indexes
CREATE INDEX IX_AuditLogs_TableName ON AUDIT_LOGS(table_name);
CREATE INDEX IX_AuditLogs_ChangedAt ON AUDIT_LOGS(changed_at DESC);

GO

PRINT 'All tables and indexes created successfully.';
GO
