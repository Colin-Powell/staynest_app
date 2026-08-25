
import fs from 'fs';
import { Pool } from 'pg';
import dotenv from 'dotenv';
dotenv.config({ path: 'backend/.env' });

async function apply() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('DATABASE_URL environment variable is required');
    process.exit(1);
  }

  const pool = new Pool({
    connectionString,
    ssl: connectionString.includes('render.com') ? { rejectUnauthorized: false } : false
  });

  try {
    const sql = fs.readFileSync('backend/scripts/add-notifications-table.sql', 'utf8');
    await pool.query(sql);
    console.log('Notifications table applied successfully');
  } catch (err) {
    console.error('Failed to apply schema:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}
apply();

