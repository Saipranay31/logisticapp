-- ═══════════════════════════════════════════════════════════════════════════════
-- MANUAL SQL: Phase 1, 2, 3 Database Schema Update
-- Run this script if Hibernate auto-update doesn't create the columns
-- ═══════════════════════════════════════════════════════════════════════════════

-- Connect to: porter_db
-- User: animeuser
-- Password: animepass
-- Database: PostgreSQL (127.0.0.1:5432)

-- ✅ PHASE 1: Add Driver Location Tracking Columns
-- These columns store the driver's current location for real-time map tracking
ALTER TABLE rides
ADD COLUMN IF NOT EXISTS driver_latitude DOUBLE PRECISION DEFAULT NULL;

ALTER TABLE rides
ADD COLUMN IF NOT EXISTS driver_longitude DOUBLE PRECISION DEFAULT NULL;

-- ✅ PHASE 2: Add Trip Start Data for Dynamic Pricing
-- These columns store the trip start location and time for fare calculation
ALTER TABLE rides
ADD COLUMN IF NOT EXISTS trip_start_latitude DOUBLE PRECISION DEFAULT NULL;

ALTER TABLE rides
ADD COLUMN IF NOT EXISTS trip_start_longitude DOUBLE PRECISION DEFAULT NULL;

ALTER TABLE rides
ADD COLUMN IF NOT EXISTS trip_start_time TIMESTAMP DEFAULT NULL;

-- ✅ Create Indexes for Performance
-- Speeds up FareCalculationService queries for IN_PROGRESS rides
CREATE INDEX IF NOT EXISTS idx_rides_status
ON rides(status);

CREATE INDEX IF NOT EXISTS idx_rides_driver_id
ON rides(driver_id);

-- ✅ Verify Migration Success
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'rides'
AND column_name IN (
  'driver_latitude',
  'driver_longitude',
  'trip_start_latitude',
  'trip_start_longitude',
  'trip_start_time'
)
ORDER BY ordinal_position;

-- Expected output: 5 rows with all columns present
-- ═══════════════════════════════════════════════════════════════════════════════
