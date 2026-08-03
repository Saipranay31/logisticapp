-- ============================================================
-- Porter Logistics Platform - Database Schema
-- PostgreSQL
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- AUTH / USERS TABLE (shared identity for all roles)
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           VARCHAR(20) UNIQUE,
    email           VARCHAR(255) UNIQUE,
    password_hash   VARCHAR(255),           -- only for ADMIN
    full_name       VARCHAR(255) NOT NULL,
    role            VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'DRIVER', 'ADMIN')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- ============================================================
-- OTP RECORDS
-- ============================================================
CREATE TABLE otp_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           VARCHAR(20) NOT NULL,
    otp_code        VARCHAR(6) NOT NULL,
    purpose         VARCHAR(30) NOT NULL DEFAULT 'LOGIN',
    is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at      TIMESTAMP NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_otp_phone ON otp_records(phone);

-- ============================================================
-- USER MODULE
-- ============================================================
CREATE TABLE user_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    avatar_url      VARCHAR(500),
    default_address_id UUID,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE user_addresses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label           VARCHAR(50) NOT NULL,       -- HOME, WORK, OTHER
    address_line    VARCHAR(500) NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_addresses_user ON user_addresses(user_id);

-- ============================================================
-- DRIVER MODULE
-- ============================================================
CREATE TABLE driver_profiles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    avatar_url      VARCHAR(500),
    license_number  VARCHAR(50),
    kyc_status      VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (kyc_status IN ('PENDING', 'SUBMITTED', 'VERIFIED', 'REJECTED')),
    is_online       BOOLEAN NOT NULL DEFAULT FALSE,
    rating          DOUBLE PRECISION NOT NULL DEFAULT 5.0,
    total_rides     INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_driver_profiles_user ON driver_profiles(user_id);
CREATE INDEX idx_driver_profiles_kyc ON driver_profiles(kyc_status);
CREATE INDEX idx_driver_profiles_online ON driver_profiles(is_online);

CREATE TABLE driver_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_profile_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    document_type   VARCHAR(50) NOT NULL,       -- LICENSE, AADHAAR, PAN, RC, INSURANCE
    document_url    VARCHAR(500) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    uploaded_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_driver_documents_profile ON driver_documents(driver_profile_id);

CREATE TABLE driver_vehicles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_profile_id UUID NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    vehicle_type    VARCHAR(30) NOT NULL CHECK (vehicle_type IN ('BIKE', 'AUTO', 'MINI_TRUCK', 'TRUCK')),
    vehicle_number  VARCHAR(20) NOT NULL,
    vehicle_model   VARCHAR(100),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_driver_vehicles_profile ON driver_vehicles(driver_profile_id);

-- ============================================================
-- RIDE MODULE
-- ============================================================
CREATE TABLE rides (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES users(id),
    driver_id           UUID REFERENCES users(id),
    vehicle_type        VARCHAR(30) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'REQUESTED'
                        CHECK (status IN ('REQUESTED','SEARCHING','ASSIGNED','ARRIVED','IN_PROGRESS','COMPLETED','CANCELLED')),

    -- Pickup
    pickup_address      VARCHAR(500) NOT NULL,
    pickup_latitude     DOUBLE PRECISION NOT NULL,
    pickup_longitude    DOUBLE PRECISION NOT NULL,

    -- Drop
    drop_address        VARCHAR(500) NOT NULL,
    drop_latitude       DOUBLE PRECISION NOT NULL,
    drop_longitude      DOUBLE PRECISION NOT NULL,

    -- Fare
    estimated_distance_km   DOUBLE PRECISION,
    estimated_duration_min  DOUBLE PRECISION,
    estimated_fare          DOUBLE PRECISION,
    actual_distance_km      DOUBLE PRECISION,
    actual_duration_min     DOUBLE PRECISION,
    actual_fare             DOUBLE PRECISION,

    -- OTP
    pickup_otp          VARCHAR(6),

    -- Timestamps
    requested_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    assigned_at         TIMESTAMP,
    arrived_at          TIMESTAMP,
    started_at          TIMESTAMP,
    completed_at        TIMESTAMP,
    cancelled_at        TIMESTAMP,
    cancelled_by        VARCHAR(20),            -- USER or DRIVER

    created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rides_user ON rides(user_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
CREATE INDEX idx_rides_status ON rides(status);
CREATE INDEX idx_rides_requested_at ON rides(requested_at);

CREATE TABLE ride_status_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id         UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    from_status     VARCHAR(30),
    to_status       VARCHAR(30) NOT NULL,
    changed_by      UUID,
    changed_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ride_status_history_ride ON ride_status_history(ride_id);

-- ============================================================
-- PAYMENT MODULE
-- ============================================================
CREATE TABLE payments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    driver_id       UUID REFERENCES users(id),
    amount          DOUBLE PRECISION NOT NULL,
    payment_method  VARCHAR(30) NOT NULL DEFAULT 'CASH' CHECK (payment_method IN ('CASH', 'UPI', 'CARD', 'WALLET')),
    payment_status  VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payments_ride ON payments(ride_id);
CREATE INDEX idx_payments_user ON payments(user_id);

-- ============================================================
-- FINANCIAL MODULE
-- ============================================================
CREATE TABLE user_spending (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    amount          DOUBLE PRECISION NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_spending_user ON user_spending(user_id);

CREATE TABLE driver_earnings (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id       UUID NOT NULL REFERENCES users(id),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    gross_amount    DOUBLE PRECISION NOT NULL,
    commission      DOUBLE PRECISION NOT NULL,
    net_amount      DOUBLE PRECISION NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_driver_earnings_driver ON driver_earnings(driver_id);

CREATE TABLE admin_revenue (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id         UUID NOT NULL REFERENCES rides(id),
    commission_amount DOUBLE PRECISION NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATION MODULE
-- ============================================================
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id),
    title           VARCHAR(255) NOT NULL,
    body            TEXT NOT NULL,
    type            VARCHAR(30) NOT NULL,       -- RIDE_UPDATE, PAYMENT, PROMO, SYSTEM
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    data            JSONB,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_read ON notifications(is_read);

-- ============================================================
-- DEVICE TOKENS (FCM Push Notifications)
-- ============================================================
CREATE TABLE device_tokens (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token           TEXT NOT NULL,
    platform        VARCHAR(20) NOT NULL DEFAULT 'ANDROID',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, token)
);

CREATE INDEX idx_device_tokens_user ON device_tokens(user_id);

-- ============================================================
-- SEED: Default admin user (password: admin123)
-- ============================================================
INSERT INTO users (phone, email, password_hash, full_name, role, is_active)
VALUES ('9999999999', 'admin@porter.com',
        '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
        'Super Admin', 'ADMIN', TRUE)
ON CONFLICT (email) DO NOTHING;
