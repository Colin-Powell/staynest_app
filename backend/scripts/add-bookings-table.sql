-- Add bookings table
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
