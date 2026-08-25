import pg from 'pg';
const { Pool } = pg;
const pool = new Pool({ connectionString: 'postgresql://postgres:postgres@localhost:5432/staynest' });

async function run() {
  try {
    const res1 = await pool.query(`SELECT COUNT(*) FROM properties`);
    console.log("Total Count:", res1.rows[0].count);
    
    const res2 = await pool.query(`
      SELECT
        p.id, p.status, u.id as landlord_id
      FROM properties p
      JOIN users u ON p.landlord_id = u.id
      LEFT JOIN bookings b ON p.id = b.property_id
      GROUP BY p.id, u.id, u.name, u.email, u.verified
    `);
    console.log("Admin query returns:", res2.rowCount);
  } catch(e) {
    console.log("Error:", e.message);
  }
  process.exit(0);
}
run();
