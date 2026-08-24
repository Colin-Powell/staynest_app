import { Pool } from 'pg';
import { env } from '../src/config.js';

const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: env.databaseUrl.includes('render.com') ? { rejectUnauthorized: false } : false
});

async function run() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS platform_settings (
      key VARCHAR(255) PRIMARY KEY,
      value JSONB NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);
  
  await pool.query(`
    INSERT INTO platform_settings (key, value)
    VALUES 
      ('general', '{"requireManualKyc": true, "autoApproveListings": false, "globalFee": 10, "defaultCurrency": "KES"}'),
      ('security', '{"enforce2FA": true, "maintenanceMode": false}')
    ON CONFLICT (key) DO NOTHING;
  `);
  console.log('Settings table initialized');
  process.exit(0);
}
run();
