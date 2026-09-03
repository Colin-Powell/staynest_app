-- Structured Kenyan location hierarchy for property intelligence.
ALTER TABLE properties ADD COLUMN IF NOT EXISTS country text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS county text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS sub_county text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS ward text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS town text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS neighborhood text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS estate_village text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS road text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS landmark text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS country text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS county text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS sub_county text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS ward text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS town text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS neighborhood text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS estate_village text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS road text;
ALTER TABLE property_drafts ADD COLUMN IF NOT EXISTS landmark text;

UPDATE properties
SET country = COALESCE(NULLIF(country, ''), 'Kenya')
WHERE country IS NULL OR country = '';

CREATE INDEX IF NOT EXISTS properties_location_taxonomy_idx
  ON properties (country, county, sub_county, ward, town, neighborhood);