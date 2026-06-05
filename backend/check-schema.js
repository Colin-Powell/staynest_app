import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // First check the verifications table schema
  const schemaResult = await client.query(`
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'verifications'
    ORDER BY ordinal_position;
  `);
  console.log('Verifications table schema:');
  console.log(schemaResult.rows);
} catch (err) {
  console.error('Error:', err);
} finally {
  client.release();
  await pool.end();
}
