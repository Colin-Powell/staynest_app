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
  lat numeric,
  lng numeric,
  landlord_id uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure lat/lng columns exist for older databases
ALTER TABLE properties ADD COLUMN IF NOT EXISTS lat numeric;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS lng numeric;

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

CREATE POLICY favorites_owner_policy ON favorites
  USING (user_id = current_setting('app.current_user_id', true)::uuid)
  WITH CHECK (user_id = current_setting('app.current_user_id', true)::uuid);

ALTER TABLE properties ENABLE ROW LEVEL SECURITY;

CREATE POLICY properties_read_all ON properties
  USING (true);

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

-- Bookings table for property bookings/reservations
CREATE TABLE IF NOT EXISTS bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id uuid NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  landlord_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  check_in_date date NOT NULL,
  check_out_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending', -- pending | confirmed | cancelled | completed
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
