CREATE TABLE IF NOT EXISTS locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,
  type TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'Kenya',
  county TEXT,
  sub_county TEXT,
  town TEXT,
  ward TEXT,
  neighborhood TEXT,
  estate_village TEXT,
  road TEXT,
  landmark TEXT,
  latitude NUMERIC,
  longitude NUMERIC,
  aliases JSONB NOT NULL DEFAULT '[]'::jsonb,
  parent_id UUID REFERENCES locations(id) ON DELETE SET NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS locations_normalized_name_idx ON locations (normalized_name);
CREATE INDEX IF NOT EXISTS locations_type_idx ON locations (type);
CREATE INDEX IF NOT EXISTS locations_county_town_idx ON locations (county, town);
CREATE INDEX IF NOT EXISTS locations_coordinates_idx ON locations (latitude, longitude);

INSERT INTO locations
  (name, normalized_name, type, country, county, sub_county, town, neighborhood, landmark, latitude, longitude, aliases)
VALUES
  ('Kilifi Town', 'kilifi town', 'town', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', NULL, NULL, NULL, NULL, '["Kilifi"]'),
  ('Mkoroshoni', 'mkoroshoni', 'neighborhood', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', 'Mkoroshoni', NULL, NULL, NULL, '["Mkoroshoni Kilifi"]'),
  ('Kibaoni', 'kibaoni', 'neighborhood', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', 'Kibaoni', NULL, NULL, NULL, '["Kibaoni Kilifi"]'),
  ('Mnarani', 'mnarani', 'neighborhood', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', 'Mnarani', NULL, NULL, NULL, '["Mnarani Kilifi"]'),
  ('Pwani University (Main Campus)', 'pwani university main campus', 'campus', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', 'Kashero', NULL, 'Pwani University (Main Campus)', -3.6199601, 39.8462317, '["Pwani University", "Pwani"]'),
  ('Mephi Hospital', 'mephi hospital', 'hospital', 'Kenya', 'Kilifi County', 'Kilifi North', 'Kilifi', 'Mkoroshoni', 'Mephi Hospital', NULL, NULL, '["Mephi", "Mephi Hospital Kilifi"]')
ON CONFLICT DO NOTHING;