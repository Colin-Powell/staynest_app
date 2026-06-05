import bcrypt from 'bcrypt';
import { Pool } from 'pg';

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/staynest';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@example.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'adminpass';
const ADMIN_NAME = process.env.ADMIN_NAME || 'Admin User';

async function main() {
  const pool = new Pool({ connectionString: DATABASE_URL });
  const client = await pool.connect();
  try {
    const hashed = await bcrypt.hash(ADMIN_PASSWORD, 10);
    const existing = await client.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [ADMIN_EMAIL]);
    if (existing.rowCount > 0) {
      console.log('Admin user already exists.');
      return;
    }

    const insert = await client.query(
      `INSERT INTO users (name, email, password_hash, role, verified)
       VALUES ($1, $2, $3, $4, true)
       RETURNING id`,
      [ADMIN_NAME, ADMIN_EMAIL, hashed, 'admin'],
    );

    console.log('Created admin user with id:', insert.rows[0].id);
  } catch (err) {
    console.error('Failed to create admin:', err);
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
