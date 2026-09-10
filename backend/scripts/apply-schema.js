import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

async function applySchema() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error(' DATABASE_URL environment variable is required');
    process.exit(1);
  }

  const sslMode = new URL(connectionString).searchParams.get('sslmode');
  const pool = new Pool({
    connectionString,
    ssl: sslMode === 'verify-full' || sslMode === 'verify-ca'
      ? { rejectUnauthorized: true }
      : sslMode === 'require'
        ? { rejectUnauthorized: false }
        : undefined,
  });

  try {
    const schemaPath = path.join(__dirname, 'init-db.sql');
    const sql = fs.readFileSync(schemaPath, 'utf8');
    await pool.query(sql);
    console.log('✅ Schema applied successfully');
  } catch (err) {
    console.error(' Failed to apply schema:', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

applySchema();