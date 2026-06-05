import { Pool } from 'pg';
import { randomUUID } from 'crypto';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  // Get user ID
  const userResult = await client.query('SELECT id FROM users WHERE email = $1;', ['oderocollonce5@gmail.com']);
  if (userResult.rows.length === 0) {
    console.log('User not found');
    process.exit(1);
  }
  
  const userId = userResult.rows[0].id;
  
  // Create approved verification record
  const verificationId = randomUUID();
  const now = new Date().toISOString();
  
  const result = await client.query(
    `INSERT INTO verifications (id, user_id, status, documents, property_data, admin_notes, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *;`,
    [
      verificationId,
      userId,
      'approved',
      JSON.stringify({ auto_approved: true }),
      JSON.stringify({ auto_approved: true }),
      'Auto-approved for testing',
      now,
      now
    ]
  );
  
  console.log('Created verification record:');
  console.log(result.rows[0]);
} catch (err) {
  console.error('Error:', err);
} finally {
  client.release();
  await pool.end();
}
