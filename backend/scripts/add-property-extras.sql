-- Extended property fields for images, amenities, and full address

ALTER TABLE properties ADD COLUMN IF NOT EXISTS images jsonb DEFAULT '[]'::jsonb;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS video_url text;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS amenities jsonb DEFAULT '[]'::jsonb;
ALTER TABLE properties ADD COLUMN IF NOT EXISTS address text;

-- Backfill images from existing image_url where missing
UPDATE properties
SET images = jsonb_build_array(image_url)
WHERE (images IS NULL OR images = '[]'::jsonb)
  AND image_url IS NOT NULL
  AND image_url <> '';
