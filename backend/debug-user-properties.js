import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // First, get the user's ID
  const userResult = await client.query(
    'SELECT id, email, role, verified FROM users WHERE email = $1;',
    ['oderocollonce5@gmail.com']
  );
  
  if (userResult.rows.length === 0) {
    console.log('No user found with email: oderocollonce5@gmail.com');
    process.exit(1);
  }
  
  const user = userResult.rows[0];
  console.log('User found:', user);
  
  // Now, get properties for this user
  const propertiesResult = await client.query(
    'SELECT id, title, category, city, price, landlord_id, created_at FROM properties WHERE landlord_id = $1;',
    [user.id]
  );
  
  console.log(`\nProperties for user ${user.email} (ID: ${user.id}):`);
  if (propertiesResult.rows.length === 0) {
    console.log('No properties found for this user');
  } else {
    console.log(`Found ${propertiesResult.rows.length} properties:`);
    propertiesResult.rows.forEach(prop => {
      console.log(`  - ID: ${prop.id}, Title: ${prop.title}, City: ${prop.city}, Price: ${prop.price}, Created: ${prop.created_at}`);
    });
  }
} catch (err) {
  console.error('Database error:', err);
} finally {
  client.release();
  await pool.end();
}
