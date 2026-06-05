import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // Get the landlord user ID
  const userResult = await client.query(
    'SELECT id FROM users WHERE email = $1;',
    ['oderocollonce5@gmail.com']
  );
  
  if (userResult.rows.length === 0) {
    console.log('User not found');
    process.exit(1);
  }
  
  const landlordId = userResult.rows[0].id;
  console.log(`Deleting old properties for landlord: ${landlordId}`);
  
  // Delete existing properties
  const deleteResult = await client.query(
    'DELETE FROM properties WHERE landlord_id = $1;',
    [landlordId]
  );
  
  console.log(`Deleted ${deleteResult.rowCount} properties`);
  
  // Insert new test properties with real image URLs
  const insertResult = await client.query(
    `INSERT INTO properties (title, description, category, city, price, bedrooms, bathrooms, area, image_url, landlord_id)
     VALUES 
       ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10),
       ($11, $12, $13, $14, $15, $16, $17, $18, $19, $10),
       ($20, $21, $22, $23, $24, $25, $26, $27, $28, $10)
     RETURNING id, title, city, price, image_url;`,
    [
      'Spacious 2BR Apartment in Westlands',
      'Beautiful modern apartment with contemporary furnishings, fully equipped kitchen, and stunning city views. Located in the prestigious Westlands area with 24/7 security.',
      'Apartment',
      'Nairobi',
      45000,
      2,
      2,
      120,
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800&q=80',
      landlordId,
      'Modern 3BR House in Karen',
      'Luxurious standalone house in the upscale Karen residential area. Features a spacious garden, parking for 2 vehicles, and modern amenities throughout.',
      'House',
      'Nairobi',
      75000,
      3,
      2,
      200,
      'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=800&q=80',
      'Contemporary 1BR Bedsitter in Kilimani',
      'Cozy and stylish bedsitter perfect for young professionals. Modern interior, balcony with city views, and convenient access to restaurants and shopping.',
      'Bedsitter',
      'Nairobi',
      28000,
      1,
      1,
      65,
      'https://images.unsplash.com/photo-1493857671505-72967e2e2760?w=800&q=80',
    ]
  );
  
  console.log('✅ Created properties with real images:');
  insertResult.rows.forEach(prop => {
    console.log(`  - ${prop.title}`);
    console.log(`    City: ${prop.city}, Price: KES ${prop.price}/month`);
    console.log(`    Image: ${prop.image_url}\n`);
  });
  
} catch (err) {
  console.error('Database error:', err);
} finally {
  client.release();
  await pool.end();
}
