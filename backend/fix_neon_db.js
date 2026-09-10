import pg from 'pg';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL environment variable is required');
}

const pool = new pg.Pool({ 
  connectionString,
  ssl: {
    rejectUnauthorized: false
  }
});

async function run() {
  try {
    console.log('Connecting to Neon database...');
    await pool.query(`
      ALTER TABLE users 
      ADD COLUMN IF NOT EXISTS referral_code VARCHAR(50) UNIQUE,
      ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES users(id),
      ADD COLUMN IF NOT EXISTS wallet_balance NUMERIC(10, 2) NOT NULL DEFAULT 0.00;
    `);

    await pool.query(`
      UPDATE users
      SET referral_code = 'SN' || UPPER(REPLACE(id::text, '-', ''))
      WHERE referral_code IS NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS idx_users_referral_code
        ON users(referral_code) WHERE referral_code IS NOT NULL;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS wallet_transactions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        amount NUMERIC(10, 2) NOT NULL,
        type VARCHAR(20) NOT NULL,
        description TEXT,
        reference_type VARCHAR(40),
        reference_id UUID,
        idempotency_key VARCHAR(160) UNIQUE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await pool.query(`
      ALTER TABLE wallet_transactions
      ADD COLUMN IF NOT EXISTS reference_type VARCHAR(40),
      ADD COLUMN IF NOT EXISTS reference_id UUID,
      ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(160);
      CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_idempotency
        ON wallet_transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;
      CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_created
        ON wallet_transactions(user_id, created_at DESC);
    `);

    console.log('Remote Database (Neon) updated successfully!');
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    await pool.end();
  }
}

run();
