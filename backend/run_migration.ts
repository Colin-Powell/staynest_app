import { pool } from './src/db.js';
import fs from 'fs';

async function migrate() {
  try {
    const sql = fs.readFileSync('scripts/add-notifications-table.sql', 'utf-8');
    await pool.query(sql);
    console.log("Migration successful");
  } catch (e) {
    console.error(e);
  } finally {
    pool.end();
  }
}
migrate();
