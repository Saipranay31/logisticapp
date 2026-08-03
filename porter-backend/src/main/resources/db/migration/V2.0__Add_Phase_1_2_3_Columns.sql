-- ═══════════════════════════════════════════════════════════════════════════════
-- Phase 1, 2, 3 Database Migration
-- Add columns for real-time location tracking, dynamic pricing, and navigation
-- ═══════════════════════════════════════════════════════════════════════════════

-- ✅ PHASE 1: Real-Time Location Tracking
-- Add driver's current location for live tracking on user's map
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_latitude DOUBLE PRECISION;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS driver_longitude DOUBLE PRECISION;

-- ✅ PHASE 2: Real-Time Dynamic Pricing
-- Add trip start location and time for dynamic fare calculation
ALTER TABLE rides ADD COLUMN IF NOT EXISTS trip_start_latitude DOUBLE PRECISION;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS trip_start_longitude DOUBLE PRECISION;
ALTER TABLE rides ADD COLUMN IF NOT EXISTS trip_start_time TIMESTAMP;

-- Create index for faster queries of in-progress rides (for fare calculation)
CREATE INDEX IF NOT EXISTS idx_rides_status ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_driver_id ON rides(driver_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- Summary of changes:
-- 1. driver_latitude/driver_longitude: Updated every 15 seconds from LocationController
-- 2. trip_start_latitude/trip_start_longitude: Captured when OTP verified
-- 3. trip_start_time: Captured when trip starts, used for fare calculation
-- 4. Indexes: Speed up FareCalculationService.findByStatus(IN_PROGRESS) queries
-- ═══════════════════════════════════════════════════════════════════════════════
