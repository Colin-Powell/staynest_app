import { Pool } from 'pg';

const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });
const client = await pool.connect();

try {
  const result = await client.query(
    'UPDATE users SET verified = true WHERE email = $1 RETURNING id, email, role, verified;',
    ['oderocollonce5@gmail.com']
  );
  if (result.rows.length > 0) {
    console.log('Updated user:', result.rows[0]);
  } else {
    console.log('No user found with that email');
  }
} catch (err) {
  console.error('Database error:', err);
} finally {
  client.release();
  await pool.end();
}
