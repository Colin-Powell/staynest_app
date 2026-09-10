import { pool } from '../db.js';

export const REFERRAL_REWARD_KES = 500;

export async function settleReferralReward(bookingId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const booking = await client.query(
      `SELECT b.id, b.tenant_id, u.referred_by
       FROM bookings b
       JOIN users u ON u.id = b.tenant_id
       WHERE b.id = $1 AND b.status = 'completed'
       FOR UPDATE OF b`,
      [bookingId],
    );
    const row = booking.rows[0];
    if (!row?.referred_by || row.referred_by === row.tenant_id) {
      await client.query('COMMIT');
      return;
    }

    const idempotencyKey = `referral-booking:${row.id}`;
    const inserted = await client.query(
      `INSERT INTO wallet_transactions
         (user_id, amount, type, description, reference_type, reference_id, idempotency_key)
       VALUES
         ($1, $2, 'referral_reward', 'Referral reward for completed booking', 'booking', $3, $4),
         ($5, $2, 'referral_reward', 'Referral reward for completing a referred booking', 'booking', $3, $4 || ':referred')
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING user_id`,
      [row.referred_by, REFERRAL_REWARD_KES, row.id, idempotencyKey, row.tenant_id],
    );

    const insertedUserIds = inserted.rows.map((insertedRow) => insertedRow.user_id);
    if (insertedUserIds.length > 0) {
      await client.query(
        `UPDATE users
         SET wallet_balance = wallet_balance + $1
         WHERE id = ANY($2::uuid[])`,
        [REFERRAL_REWARD_KES, insertedUserIds],
      );
    }

    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}