import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  const userResult = await client.query('SELECT id, email, verified FROM users WHERE email = $1;', ['oderocollonce5@gmail.com']);
  console.log('User:', userResult.rows[0]);
  
  if (userResult.rows.length > 0) {
    const userId = userResult.rows[0].id;
    const verResult = await client.query('SELECT * FROM verifications WHERE user_id = $1;', [userId]);
    console.log('Verification records:', verResult.rows);
  }
} catch (err) {
  console.error('Error:', err);
} finally {
  client.release();
  await pool.end();
}
