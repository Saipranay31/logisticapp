-- ✅ Add full_name field to driver_profiles table for driver name tracking during KYC

ALTER TABLE driver_profiles ADD COLUMN full_name VARCHAR(255);

-- Create index for faster lookups
CREATE INDEX idx_driver_profiles_full_name ON driver_profiles(full_name);

-- Sync existing driver profiles with User fullName
UPDATE driver_profiles dp
SET full_name = (
    SELECT u.full_name FROM users u WHERE u.id = dp.user_id
)
WHERE full_name IS NULL;
