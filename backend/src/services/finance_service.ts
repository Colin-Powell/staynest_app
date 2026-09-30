import { PoolClient } from 'pg';
import { pool } from '../db.js';

type LedgerEntry = {
  userId: string;
  amount: number;
  type: string;
  description: string;
  referenceType: string;
  referenceId?: string;
  idempotencyKey: string;
};

async function postLedgerEntry(client: PoolClient, entry: LedgerEntry): Promise<boolean> {
  const result = await client.query(
    `INSERT INTO wallet_transactions
       (user_id, amount, type, description, reference_type, reference_id, idempotency_key, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'posted')
     ON CONFLICT (idempotency_key) DO NOTHING
     RETURNING id`,
    [entry.userId, entry.amount, entry.type, entry.description, entry.referenceType,
      entry.referenceId ?? null, entry.idempotencyKey],
  );
  if (result.rows.length === 0) return false;

  await client.query(
    `UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2`,
    [entry.amount, entry.userId],
  );
  return true;
}

export async function payBookingFromWallet(
  bookingId: string,
  payerId: string,
  idempotencyKey: string,
): Promise<{ escrowId: string; amount: number }> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const bookingResult = await client.query(
      `SELECT id, tenant_id, landlord_id, total_price, status
       FROM bookings WHERE id = $1 FOR UPDATE`,
      [bookingId],
    );
    const booking = bookingResult.rows[0];
    if (!booking || booking.tenant_id !== payerId) throw new Error('Booking is not payable by this user.');
    if (!['pending', 'confirmed'].includes(booking.status)) throw new Error('Booking is not payable in its current state.');

    const existing = await client.query(
      'SELECT id, amount FROM booking_escrows WHERE booking_id = $1 FOR UPDATE', [bookingId],
    );
    if (existing.rows.length > 0) {
      await client.query('COMMIT');
      return { escrowId: existing.rows[0].id, amount: Number(existing.rows[0].amount) };
    }

    const amount = Number(booking.total_price);
    const balance = await client.query('SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [payerId]);
    if (Number(balance.rows[0]?.wallet_balance ?? 0) < amount) throw new Error('Insufficient wallet balance.');

    await postLedgerEntry(client, {
      userId: payerId,
      amount: -amount,
      type: 'booking_payment',
      description: 'Booking payment held in escrow',
      referenceType: 'booking',
      referenceId: bookingId,
      idempotencyKey: `booking-payment:${idempotencyKey}`,
    });
    const escrow = await client.query(
      `INSERT INTO booking_escrows (booking_id, payer_id, payee_id, amount)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [bookingId, payerId, booking.landlord_id, amount],
    );
    await client.query('COMMIT');
    return { escrowId: escrow.rows[0].id, amount };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function createAndPayBookingFromWallet(input: {
  propertyId: string;
  tenantId: string;
  checkInDate: string;
  checkOutDate: string;
  notes?: string;
  idempotencyKey: string;
}): Promise<{
  booking: Record<string, unknown>;
  escrowId: string;
  amount: number;
  created: boolean;
}> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      'SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))',
      [input.tenantId, input.idempotencyKey],
    );

    const existing = await client.query(
      `SELECT b.*, e.id AS escrow_id
       FROM wallet_transactions wt
       JOIN booking_escrows e ON e.booking_id = wt.reference_id
       JOIN bookings b ON b.id = e.booking_id
       WHERE wt.user_id = $1 AND wt.type = 'booking_payment'
         AND wt.idempotency_key = $2
       FOR UPDATE OF b`,
      [input.tenantId, `booking-payment:${input.idempotencyKey}`],
    );
    if (existing.rows.length > 0) {
      const row = existing.rows[0];
      await client.query('COMMIT');
      const { escrow_id: escrowId, ...booking } = row;
      return {
        booking,
        escrowId,
        amount: Number(row.total_price),
        created: false,
      };
    }

    const checkIn = new Date(input.checkInDate);
    const checkOut = new Date(input.checkOutDate);
    if (
      !Number.isFinite(checkIn.getTime()) ||
      !Number.isFinite(checkOut.getTime()) ||
      checkOut <= checkIn
    ) {
      throw new Error('Invalid booking date range.');
    }

    const propertyResult = await client.query(
      'SELECT id, landlord_id, price FROM properties WHERE id = $1 FOR UPDATE',
      [input.propertyId],
    );
    const property = propertyResult.rows[0];
    if (!property) throw new Error('Property not found.');
    if (!property.landlord_id) throw new Error('Property has no landlord assigned.');
    if (property.landlord_id === input.tenantId) {
      throw new Error('Landlords cannot book their own property.');
    }

    const overlap = await client.query(
      `SELECT id FROM bookings
       WHERE property_id = $1
         AND (status = 'confirmed' OR (status = 'pending' AND EXISTS (
           SELECT 1 FROM booking_escrows e
           WHERE e.booking_id = bookings.id AND e.status = 'held'
         )))
         AND (check_in_date, check_out_date) OVERLAPS ($2::date, $3::date)
       LIMIT 1`,
      [input.propertyId, input.checkInDate, input.checkOutDate],
    );
    if (overlap.rows.length > 0) {
      throw new Error('Property is already booked for these dates.');
    }

    const activeBooking = await client.query(
      `SELECT id FROM bookings
       WHERE property_id = $1 AND tenant_id = $2
         AND status IN ('pending', 'confirmed')
       LIMIT 1`,
      [input.propertyId, input.tenantId],
    );
    if (activeBooking.rows.length > 0) {
      throw new Error('You already have an active booking or request for this property.');
    }

    const userResult = await client.query(
      'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE',
      [input.tenantId],
    );
    const nightlyPrice = Number(property.price);
    const nights = Math.ceil(
      (Date.UTC(checkOut.getUTCFullYear(), checkOut.getUTCMonth(), checkOut.getUTCDate()) -
        Date.UTC(checkIn.getUTCFullYear(), checkIn.getUTCMonth(), checkIn.getUTCDate())) /
        86400000,
    );
    const amount = nights * nightlyPrice;
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('The booking total is invalid.');
    }
    if (Number(userResult.rows[0]?.wallet_balance ?? 0) < amount) {
      throw new Error('Insufficient wallet balance. Add funds and try again.');
    }

    const bookingResult = await client.query(
      `INSERT INTO bookings
         (property_id, tenant_id, landlord_id, check_in_date, check_out_date,
          status, total_price, notes)
       VALUES ($1, $2, $3, $4::date, $5::date, 'pending', $6, $7)
       RETURNING *`,
      [
        input.propertyId,
        input.tenantId,
        property.landlord_id,
        input.checkInDate,
        input.checkOutDate,
        amount,
        input.notes?.trim() || null,
      ],
    );
    const booking = bookingResult.rows[0] as Record<string, unknown>;

    await postLedgerEntry(client, {
      userId: input.tenantId,
      amount: -amount,
      type: 'booking_payment',
      description: 'Booking payment held in escrow',
      referenceType: 'booking',
      referenceId: String(booking.id),
      idempotencyKey: `booking-payment:${input.idempotencyKey}`,
    });

    const escrowResult = await client.query(
      `INSERT INTO booking_escrows (booking_id, payer_id, payee_id, amount)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [booking.id, input.tenantId, property.landlord_id, amount],
    );

    await client.query('COMMIT');
    return {
      booking,
      escrowId: escrowResult.rows[0].id,
      amount,
      created: true,
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function settleEscrow(bookingId: string, action: 'release' | 'refund'): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const escrowResult = await client.query(
      `SELECT * FROM booking_escrows WHERE booking_id = $1 FOR UPDATE`, [bookingId],
    );
    const escrow = escrowResult.rows[0];
    if (!escrow || escrow.status !== 'held') {
      await client.query('COMMIT');
      return;
    }
    const recipient = action === 'release' ? escrow.payee_id : escrow.payer_id;
    await postLedgerEntry(client, {
      userId: recipient,
      amount: Number(escrow.amount),
      type: action === 'release' ? 'escrow_release' : 'escrow_refund',
      description: action === 'release' ? 'Booking escrow released' : 'Booking payment refunded',
      referenceType: 'booking_escrow',
      referenceId: escrow.id,
      idempotencyKey: `escrow-${action}:${escrow.id}`,
    });
    await client.query(
      `UPDATE booking_escrows SET status = $1, ${action === 'release' ? 'released_at' : 'refunded_at'} = NOW()
       WHERE id = $2`,
      [action === 'release' ? 'released' : 'refunded', escrow.id],
    );
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function settleWalletTopup(transactionId: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const transaction = await client.query(
      `SELECT id, user_id, amount, status FROM payment_transactions WHERE id = $1 FOR UPDATE`,
      [transactionId],
    );
    const row = transaction.rows[0];
    if (row && row.status === 'completed') {
      await postLedgerEntry(client, {
        userId: row.user_id,
        amount: Number(row.amount),
        type: 'wallet_topup',
        description: 'M-Pesa wallet top-up',
        referenceType: 'payment_transaction',
        referenceId: row.id,
        idempotencyKey: `wallet-topup:${row.id}`,
      });
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}