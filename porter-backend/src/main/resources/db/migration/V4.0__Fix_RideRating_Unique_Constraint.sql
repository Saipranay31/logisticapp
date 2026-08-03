-- Drop old unique constraint on ride_id alone (Hibernate-generated name)
-- (allows both user and driver to rate the same ride)
ALTER TABLE ride_ratings DROP CONSTRAINT IF EXISTS uk_bb67kb145usjjih6mig5s8k44;
ALTER TABLE ride_ratings DROP CONSTRAINT IF EXISTS ride_ratings_ride_id_key;
ALTER TABLE ride_ratings DROP CONSTRAINT IF EXISTS uq_ride_rater;

-- Add composite unique constraint: one rating per (ride, rater)
ALTER TABLE ride_ratings ADD CONSTRAINT uq_ride_rater UNIQUE (ride_id, rater_id);
