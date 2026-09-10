import { pool } from '../db.js';
async function postLedgerEntry(client, entry) {
    const result = await client.query(`INSERT INTO wallet_transactions
       (user_id, amount, type, description, reference_type, reference_id, idempotency_key, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'posted')
     ON CONFLICT (idempotency_key) DO NOTHING
     RETURNING id`, [entry.userId, entry.amount, entry.type, entry.description, entry.referenceType,
        entry.referenceId ?? null, entry.idempotencyKey]);
    if (result.rows.length === 0)
        return false;
    await client.query(`UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2`, [entry.amount, entry.userId]);
    return true;
}
export async function payBookingFromWallet(bookingId, payerId, idempotencyKey) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const bookingResult = await client.query(`SELECT id, tenant_id, landlord_id, total_price, status
       FROM bookings WHERE id = $1 FOR UPDATE`, [bookingId]);
        const booking = bookingResult.rows[0];
        if (!booking || booking.tenant_id !== payerId)
            throw new Error('Booking is not payable by this user.');
        if (!['pending', 'confirmed'].includes(booking.status))
            throw new Error('Booking is not payable in its current state.');
        const existing = await client.query('SELECT id, amount FROM booking_escrows WHERE booking_id = $1 FOR UPDATE', [bookingId]);
        if (existing.rows.length > 0) {
            await client.query('COMMIT');
            return { escrowId: existing.rows[0].id, amount: Number(existing.rows[0].amount) };
        }
        const amount = Number(booking.total_price);
        const balance = await client.query('SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [payerId]);
        if (Number(balance.rows[0]?.wallet_balance ?? 0) < amount)
            throw new Error('Insufficient wallet balance.');
        await postLedgerEntry(client, {
            userId: payerId,
            amount: -amount,
            type: 'booking_payment',
            description: 'Booking payment held in escrow',
            referenceType: 'booking',
            referenceId: bookingId,
            idempotencyKey: `booking-payment:${idempotencyKey}`,
        });
        const escrow = await client.query(`INSERT INTO booking_escrows (booking_id, payer_id, payee_id, amount)
       VALUES ($1, $2, $3, $4) RETURNING id`, [bookingId, payerId, booking.landlord_id, amount]);
        await client.query('COMMIT');
        return { escrowId: escrow.rows[0].id, amount };
    }
    catch (error) {
        await client.query('ROLLBACK');
        throw error;
    }
    finally {
        client.release();
    }
}
export async function settleEscrow(bookingId, action) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const escrowResult = await client.query(`SELECT * FROM booking_escrows WHERE booking_id = $1 FOR UPDATE`, [bookingId]);
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
        await client.query(`UPDATE booking_escrows SET status = $1, ${action === 'release' ? 'released_at' : 'refunded_at'} = NOW()
       WHERE id = $2`, [action === 'release' ? 'released' : 'refunded', escrow.id]);
        await client.query('COMMIT');
    }
    catch (error) {
        await client.query('ROLLBACK');
        throw error;
    }
    finally {
        client.release();
    }
}
export async function settleWalletTopup(transactionId) {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const transaction = await client.query(`SELECT id, user_id, amount, status FROM payment_transactions WHERE id = $1 FOR UPDATE`, [transactionId]);
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
    }
    catch (error) {
        await client.query('ROLLBACK');
        throw error;
    }
    finally {
        client.release();
    }
}
//# sourceMappingURL=finance_service.js.map