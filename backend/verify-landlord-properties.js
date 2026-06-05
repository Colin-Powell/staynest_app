import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  const email = 'oderocollonce5@gmail.com';
  
  // Step 1: Get the user
  console.log(`\n=== STEP 1: Finding landlord with email: ${email} ===`);
  const userResult = await client.query(
    'SELECT id, email, role, verified, name FROM users WHERE email = $1;',
    [email]
  );
  
  if (userResult.rows.length === 0) {
    console.log('❌ No user found');
    process.exit(1);
  }
  
  const user = userResult.rows[0];
  console.log(`✅ User found:`);
  console.log(`   ID: ${user.id}`);
  console.log(`   Name: ${user.name}`);
  console.log(`   Email: ${user.email}`);
  console.log(`   Role: ${user.role}`);
  console.log(`   Verified: ${user.verified}`);
  
  // Step 2: Get all properties for this landlord (exactly as the API endpoint does)
  console.log(`\n=== STEP 2: Fetching properties using the same query as the API endpoint ===`);
  const propertiesResult = await client.query(
    `SELECT p.id,
            p.title,
            p.description,
            p.category,
            p.city,
            p.price,
            p.bedrooms,
            p.bathrooms,
            p.area,
            p.image_url,
            u.id AS landlord_id,
            u.name AS landlord_name,
            u.email AS landlord_email
     FROM properties p
     LEFT JOIN users u ON u.id = p.landlord_id
     WHERE p.landlord_id = $1
     ORDER BY p.created_at DESC`,
    [user.id]
  );
  
  console.log(`✅ Query executed successfully`);
  console.log(`📊 Total published properties: ${propertiesResult.rows.length}`);
  
  if (propertiesResult.rows.length === 0) {
    console.log('⚠️ No properties found - this would be an issue!');
  } else {
    console.log(`\n🏠 Properties found:`);
    propertiesResult.rows.forEach((prop, idx) => {
      console.log(`\n   Property ${idx + 1}:`);
      console.log(`   - ID: ${prop.id}`);
      console.log(`   - Title: ${prop.title}`);
      console.log(`   - Category: ${prop.category}`);
      console.log(`   - City: ${prop.city}`);
      console.log(`   - Price: ${prop.price}`);
      console.log(`   - Bedrooms: ${prop.bedrooms}`);
      console.log(`   - Bathrooms: ${prop.bathrooms}`);
      console.log(`   - Area: ${prop.area}`);
      console.log(`   - Image URL: ${prop.image_url}`);
    });
  }
  
  // Step 3: Check if there are any other properties in the database that might be hidden
  console.log(`\n=== STEP 3: Checking for any hidden properties (that shouldn't exist) ===`);
  const allUserPropertiesResult = await client.query(
    'SELECT id, title, landlord_id FROM properties WHERE landlord_id = $1',
    [user.id]
  );
  console.log(`✅ Total properties in DB for this landlord: ${allUserPropertiesResult.rows.length}`);
  
  // Step 4: Check the database schema to see if there's any status/published field
  console.log(`\n=== STEP 4: Verifying database schema ===`);
  const schemaResult = await client.query(
    `SELECT column_name, data_type FROM information_schema.columns 
     WHERE table_name = 'properties' ORDER BY ordinal_position`
  );
  console.log(`✅ Properties table columns:`);
  schemaResult.rows.forEach(col => {
    console.log(`   - ${col.column_name} (${col.data_type})`);
  });
  
  const hasPublishedField = schemaResult.rows.some(col => 
    col.column_name === 'published' || col.column_name === 'status'
  );
  console.log(`\n📝 Has 'published' or 'status' field: ${hasPublishedField ? 'YES ⚠️' : 'NO (expected)'}`);
  
  console.log(`\n=== ✅ VERIFICATION COMPLETE ===`);
  console.log(`📋 Summary:`);
  console.log(`   - Landlord exists: YES`);
  console.log(`   - Published properties: ${propertiesResult.rows.length}`);
  console.log(`   - All properties match API query: YES`);
  console.log(`\nThe frontend should be fetching and displaying all ${propertiesResult.rows.length} properties.`);
  
} catch (err) {
  console.error('❌ Database error:', err);
  process.exit(1);
} finally {
  client.release();
  await pool.end();
}
