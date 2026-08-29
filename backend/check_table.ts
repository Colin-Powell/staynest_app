import { pool } from './src/db.js';

async function check() {
  try {
    const res = await pool.query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notifications')");
    console.log("Table exists:", res.rows[0].exists);
  } catch (e) {
    console.error(e);
  } finally {
    pool.end();
  }
}
check();
