import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // Create a test property for the landlord
  const result = await client.query(
    `INSERT INTO properties (
      title, description, category, city, price, bedrooms, bathrooms, area, 
      image_url, lat, lng, landlord_id
    ) VALUES (
      'Modern Apartment in Westlands', 
      'A beautifully designed apartment with modern amenities in the heart of Westlands. Perfect for professionals.',
      'Apartment',
      'Nairobi',
      45000,
      2,
      1,
      80,
      'https://images.unsplash.com/photo-1554995207-c18c203602cb?w=400',
      -1.2763,
      36.7965,
      $1
    )
    RETURNING id, title, city, price, landlord_id;`,
    ['cee785b0-a0b8-4291-a06e-43638fdf6ef0']
  );
  
  console.log('Test property created successfully:');
  console.log(result.rows[0]);
  
  // Verify it was saved
  const verifyResult = await client.query(
    'SELECT COUNT(*) as count FROM properties WHERE landlord_id = $1;',
    ['cee785b0-a0b8-4291-a06e-43638fdf6ef0']
  );
  
  console.log(`\nTotal properties for user: ${verifyResult.rows[0].count}`);
  
} catch (err) {
  console.error('Database error:', err);
} finally {
  client.release();
  await pool.end();
}
