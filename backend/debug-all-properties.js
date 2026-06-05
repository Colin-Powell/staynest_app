import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // Check all properties
  const allPropertiesResult = await client.query(
    'SELECT id, title, category, city, price, landlord_id, created_at FROM properties ORDER BY created_at DESC LIMIT 20;'
  );
  
  console.log('Last 20 properties in database:');
  if (allPropertiesResult.rows.length === 0) {
    console.log('No properties found in database');
  } else {
    allPropertiesResult.rows.forEach(prop => {
      console.log(`  - ID: ${prop.id}, Title: ${prop.title}, City: ${prop.city}, Landlord ID: ${prop.landlord_id}, Created: ${prop.created_at}`);
    });
  }
  
  // Check for NULL landlord_id
  const nullLandlordResult = await client.query(
    'SELECT id, title, category, city, price, landlord_id, created_at FROM properties WHERE landlord_id IS NULL;'
  );
  
  console.log(`\nProperties with NULL landlord_id: ${nullLandlordResult.rows.length}`);
  if (nullLandlordResult.rows.length > 0) {
    nullLandlordResult.rows.forEach(prop => {
      console.log(`  - ID: ${prop.id}, Title: ${prop.title}, City: ${prop.city}, Created: ${prop.created_at}`);
    });
  }
  
} catch (err) {
  console.error('Database error:', err);
} finally {
  client.release();
  await pool.end();
}
