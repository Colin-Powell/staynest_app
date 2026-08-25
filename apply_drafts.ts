import { query } from './backend/src/db.js';

async function run() {
  await query(`
    CREATE TABLE IF NOT EXISTS property_drafts (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      landlord_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      title text,
      description text,
      category text,
      city text,
      address text,
      price numeric,
      bedrooms integer,
      bathrooms integer,
      area numeric,
      amenities jsonb,
      lat numeric,
      lng numeric,
      photos jsonb,
      created_at timestamp with time zone DEFAULT now(),
      updated_at timestamp with time zone DEFAULT now()
    );
  `);
  console.log('Drafts table created!');
  process.exit(0);
}

run().catch(console.error);
