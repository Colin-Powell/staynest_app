-- staynest backend database schema

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone text,
  password_hash text NOT NULL,
  role text NOT NULL DEFAULT 'tenant',
  avatar text,
  verified boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS settings jsonb DEFAULT '{"push": true, "email": true, "two_factor": false}'::jsonb;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_name text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_type text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_description text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS tax_id text;
ALTER TABLE users ADD COLUMN IF NOT EXISTS years_in_business integer;

CREATE TABLE IF NOT EXISTS properties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  city text NOT NULL,
  price numeric NOT NULL,
  bedrooms integer NOT NULL DEFAULT 1,
  bathrooms integer NOT NULL DEFAULT 1,
  area integer NOT NULL DEFAULT 0,
  image_url text NOT NULL,
  images jsonb DEFAULT '[]'::jsonb,
  amenities jsonb DEFAULT '[]'::jsonb,
  address text,
  lat numeric,
  lng numeric,
  landlord_id uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  average_rating numeric DEFAULT 0,
  review_count integer DEFAULT 0
);

-- Ensure lat/lng columns exist for older databases
ALTER TABLE properties ADD COLUMN IF NOT EXISTS lat numeric;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS lng numeric;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS images jsonb DEFAULT '[]'::jsonb;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS amenities jsonb DEFAULT '[]'::jsonb;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS address text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS average_rating numeric DEFAULT 0;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 0;

CREATE TABLE IF NOT EXISTS verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'submitted', -- submitted | under_review | manual_review | approved | rejected
  documents jsonb, -- { id_photo: url, utility_bill: url, selfie: url }
  property_data jsonb, -- basic listing info supplied by landlord
  admin_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS favorites (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, property_id)
);

ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS favorites_owner_policy ON favorites;
CREATE POLICY favorites_owner_policy ON favorites
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS properties_read_all ON properties;
CREATE POLICY properties_read_all ON properties
  USING (true);

DROP POLICY IF EXISTS properties_manage_own ON properties;
CREATE POLICY properties_manage_own ON properties
  USING (landlord_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (landlord_id = current_setting('app.current_user_id', true)::uuid);

-- Sample data can be inserted here after creating hashed passwords.

-- Tenant profiles (survey) to support personalized recommendations
CREATE TABLE IF NOT EXISTS tenant_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  monthly_income numeric,
  budget_min numeric,
  budget_max numeric,
  status text, -- student | employed | self-employed | unemployed
  household_size integer,
  pets boolean DEFAULT false,
  preferred_categories text[],
  preferred_cities text[],
  move_in_date date,
  opt_in_personalized boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure array columns exist for older DBs
ALTER TABLE tenant_profiles ADD COLUMN IF NOT EXISTS preferred_categories text[];
ALTER TABLE tenant_profiles ADD COLUMN IF NOT EXISTS preferred_cities text[];

-- Consent and retention fields
ALTER TABLE tenant_profiles ADD COLUMN IF NOT EXISTS consent_given boolean DEFAULT false;
ALTER TABLE tenant_profiles ADD COLUMN IF NOT EXISTS consent_at timestamptz;
ALTER TABLE tenant_profiles ADD COLUMN IF NOT EXISTS data_retention_days integer DEFAULT 365;

-- Data deletion requests table to track user requests for account/data removal
CREATE TABLE IF NOT EXISTS deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason text,
  status text NOT NULL DEFAULT 'pending', -- pending | processing | completed | rejected
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE deletion_requests ADD COLUMN IF NOT EXISTS reason text;
ALTER TABLE deletion_requests ADD COLUMN IF NOT EXISTS status text;

-- Messages table for persisting chat history
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for efficient message retrieval by conversation pair
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(from_user_id, to_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_to_user ON messages(to_user_id, created_at DESC);

-- Message read tracking:
-- Each user records which specific message IDs have been read.
-- This enables unread_count computation for the conversations list.
CREATE TABLE IF NOT EXISTS message_reads (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_id uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, message_id)
);

CREATE INDEX IF NOT EXISTS idx_message_reads_user_id ON message_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_message_reads_message_id ON message_reads(message_id);

-- Bookings table for property bookings/reservations
CREATE TABLE IF NOT EXISTS bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending | confirmed | cancelled | rejected | completed
  total_price numeric NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_bookings_tenant ON bookings(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_landlord ON bookings(landlord_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_property ON bookings(property_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- Property Availability blocks (for manual landlord blocks)
CREATE TABLE IF NOT EXISTS property_availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  block_date date NOT NULL,
  available boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(property_id, block_date)
);
CREATE INDEX IF NOT EXISTS idx_availability_property_date ON property_availability(property_id, block_date);

-- StayNest Engagement Analytics Tables

-- 1. Event Tracking Table (Foundation Layer)
CREATE TABLE IF NOT EXISTS engagement_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  event_type text NOT NULL, -- property_view, property_click, property_impression, property_save, property_share, etc.
  session_id text,
  duration_ms integer DEFAULT 0, -- For time-based tracking
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure session_id exists for legacy tables before index creation
ALTER TABLE engagement_events ADD COLUMN IF NOT EXISTS session_id text;

CREATE INDEX IF NOT EXISTS idx_events_property_type ON engagement_events(property_id, event_type);
CREATE INDEX IF NOT EXISTS idx_events_user_type ON engagement_events(user_id, event_type);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON engagement_events(created_at);
CREATE INDEX IF NOT EXISTS idx_events_session ON engagement_events(session_id);

-- 2. Engagement Aggregation Layer
CREATE TABLE IF NOT EXISTS property_analytics (
  property_id uuid PRIMARY KEY REFERENCES properties(id) ON DELETE CASCADE,
  views integer DEFAULT 0,
  unique_views integer DEFAULT 0,
  impressions integer DEFAULT 0,
  clicks integer DEFAULT 0,
  saves integer DEFAULT 0,
  shares integer DEFAULT 0,
  chats integer DEFAULT 0,
  bookings_completed integer DEFAULT 0,
  booking_requested integer DEFAULT 0,
  bookings_confirmed integer DEFAULT 0,
  avg_time_spent_ms numeric DEFAULT 0,
  engagement_score numeric DEFAULT 0,
  velocity_score numeric DEFAULT 0, -- For Trend Detection
  last_event_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. User Behavioral Profiles
CREATE TABLE IF NOT EXISTS user_engagement_profiles (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  total_sessions integer DEFAULT 0,
  search_count integer DEFAULT 0,
  last_active_at timestamptz DEFAULT now(),
  intent_score numeric DEFAULT 0, -- High intent users detection
  browsing_patterns jsonb DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 4. Search Events Table (Demand Prediction)
CREATE TABLE IF NOT EXISTS search_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  session_id text,
  query text,
  filters jsonb DEFAULT '{}'::jsonb,
  location_intent text,
  results_count integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure session_id exists for legacy search_events tables
ALTER TABLE search_events ADD COLUMN IF NOT EXISTS session_id text;

-- 5. Promotion System Table (Monetization)
CREATE TABLE IF NOT EXISTS promotion_campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  landlord_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  package_type text NOT NULL, -- basic, premium, elite
  boost_score integer DEFAULT 0,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  active boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promotions_active ON promotion_campaigns(property_id) WHERE active = true;

-- 6. Unique View Tracking (Anti-Inflation)
CREATE TABLE IF NOT EXISTS property_unique_views (
  property_id uuid REFERENCES properties(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  viewed_date date NOT NULL DEFAULT CURRENT_DATE,
  PRIMARY KEY (property_id, user_id, viewed_date)
);

-- Update property_analytics with missing columns for upgraded ranking
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS impressions integer DEFAULT 0;
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS clicks integer DEFAULT 0;
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS bookings_confirmed integer DEFAULT 0;
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS booking_requested integer DEFAULT 0;
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS bookings_completed integer DEFAULT 0;
ALTER TABLE property_analytics ADD COLUMN IF NOT EXISTS unique_views integer DEFAULT 0;

-- Reviews Table for properties
CREATE TABLE IF NOT EXISTS reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE, -- Link to a specific booking
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  reviewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  landlord_response text, -- Optional response from the landlord
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (booking_id, reviewer_id) -- Ensure one review per booking per user
);

-- Index for efficient review retrieval by property
CREATE INDEX IF NOT EXISTS idx_reviews_property_id ON reviews(property_id, created_at DESC);
-- Index for efficient review retrieval by reviewer
CREATE INDEX IF NOT EXISTS idx_reviews_reviewer_id ON reviews(reviewer_id, created_at DESC);

-- Function to update property average rating and review count
CREATE OR REPLACE FUNCTION update_property_rating()
RETURNS TRIGGER AS $$
DECLARE
  prop_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    prop_id = OLD.property_id;
  ELSE
    prop_id = NEW.property_id;
  END IF;

  UPDATE properties
  SET
    average_rating = (SELECT COALESCE(AVG(rating), 0) FROM reviews WHERE property_id = prop_id),
    review_count = (SELECT COUNT(*) FROM reviews WHERE property_id = prop_id),
    updated_at = NOW()
  WHERE id = prop_id;

  RETURN NEW; -- For AFTER triggers, returning NEW or OLD doesn't affect the result
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function after any INSERT, UPDATE, or DELETE on the reviews table
DROP TRIGGER IF EXISTS after_review_change ON reviews;
CREATE TRIGGER after_review_change
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_property_rating();

-- Review Reports Table
CREATE TABLE IF NOT EXISTS review_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE SET NULL, -- User who reported
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending | reviewed | resolved | rejected
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
