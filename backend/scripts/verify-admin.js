import { Pool } from 'pg';

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/staynest';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'oderocollince5@gmail.com';

async function main() {
  const pool = new Pool({ connectionString: DATABASE_URL });
  const client = await pool.connect();
  try {
    const result = await client.query(
      `UPDATE users 
       SET verified = true 
       WHERE email = $1 
       RETURNING id, email, verified`,
      [ADMIN_EMAIL]
    );

    if (result.rowCount > 0) {
      console.log('✓ Admin user marked as verified:', result.rows[0]);
    } else {
      console.log('✗ Admin user not found with email:', ADMIN_EMAIL);
    }
  } catch (err) {
    console.error('Failed to verify admin:', err);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run immediately when executed as an ESM script
try {
  await main();
} catch (err) {
  console.error(err);
  process.exitCode = 1;
}
