import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { pool } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { initiateSTKPush } from '../services/mpesa.js';
import { payBookingFromWallet } from '../services/finance_service.js';

const router = Router();

router.get('/', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      'SELECT wallet_balance, referral_code FROM users WHERE id = $1 LIMIT 1',
      [req.auth!.id],
    );
    if (result.rowCount === 0) return res.status(404).json({ error: 'User not found.' });
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.get('/transactions', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT id, amount, type, description, reference_type, reference_id, created_at
       FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100`,
      [req.auth!.id],
    );
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

router.get('/withdrawals', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT id, amount, status, failure_reason, processed_at, created_at
       FROM wallet_withdrawals WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.auth!.id],
    );
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

router.get('/escrow/:bookingId', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT e.id, e.booking_id, e.amount, e.status, e.funded_at, e.released_at, e.refunded_at
       FROM booking_escrows e
       WHERE e.booking_id = $1 AND (e.payer_id = $2 OR e.payee_id = $2)`,
      [req.params.bookingId, req.auth!.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Escrow not found.' });
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.post('/top-up', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const amount = Number(req.body?.amount);
    const paymentMethodId = String(req.body?.paymentMethodId ?? '');
    if (!Number.isFinite(amount) || amount < 10 || amount > 150000) {
      return res.status(400).json({ error: 'Top-up amount must be between KES 10 and KES 150,000.' });
    }
    const method = await query(
      `SELECT type, account_number FROM landlord_payment_methods
       WHERE id = $1 AND user_id = $2 LIMIT 1`,
      [paymentMethodId, req.auth!.id],
    );
    if (method.rowCount === 0 || method.rows[0].type !== 'mpesa') {
      return res.status(400).json({ error: 'Select a saved M-Pesa payment method.' });
    }
    const stk = await initiateSTKPush({
      phone: method.rows[0].account_number,
      amount,
      reference: `WALLET-${req.auth!.id.slice(0, 8)}-${Date.now()}`.slice(0, 20),
      description: 'StayNest wallet top-up',
      email: req.auth!.email,
    });
    const transaction = await query(
      `INSERT INTO payment_transactions
       (user_id, transaction_type, amount, currency, payment_method, status, checkout_request_id, metadata)
       VALUES ($1, 'wallet_topup', $2, 'KES', 'mpesa', 'processing', $3, $4)
       RETURNING id`,
      [req.auth!.id, amount, stk.CheckoutRequestID, { paymentMethodId }],
    );
    res.status(201).json({ data: { transactionId: transaction.rows[0].id, checkoutRequestId: stk.CheckoutRequestID } });
  } catch (error) {
    next(error);
  }
});

router.post('/withdraw', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  const client = await pool.connect();
  try {
    const amount = Number(req.body?.amount);
    const paymentMethodId = String(req.body?.paymentMethodId ?? '');
    const idempotencyKey = String(req.body?.idempotencyKey ?? '');
    if (!Number.isFinite(amount) || amount < 50 || amount > 150000 || !idempotencyKey) {
      return res.status(400).json({ error: 'Valid amount and idempotencyKey are required.' });
    }
    await client.query('BEGIN');
    const method = await client.query(
      `SELECT id, type FROM landlord_payment_methods WHERE id = $1 AND user_id = $2 LIMIT 1`,
      [paymentMethodId, req.auth!.id],
    );
    if (method.rows.length === 0) throw new Error('Payment method not found.');
    if (!['mpesa', 'bank_transfer'].includes(method.rows[0].type)) {
      throw new Error('Withdrawals require an M-Pesa or bank payment method.');
    }
    const existing = await client.query(
      `SELECT id, status FROM wallet_withdrawals WHERE idempotency_key = $1 AND user_id = $2`,
      [idempotencyKey, req.auth!.id],
    );
    if (existing.rows.length > 0) {
      await client.query('COMMIT');
      return res.status(200).json({ data: existing.rows[0] });
    }
    const user = await client.query('SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [req.auth!.id]);
    if (Number(user.rows[0]?.wallet_balance ?? 0) < amount) throw new Error('Insufficient wallet balance.');
    const withdrawal = await client.query(
      `INSERT INTO wallet_withdrawals (user_id, payment_method_id, amount, idempotency_key)
       VALUES ($1, $2, $3, $4) RETURNING id, status`,
      [req.auth!.id, paymentMethodId, amount, idempotencyKey],
    );
    await client.query(
      `INSERT INTO wallet_transactions
       (user_id, amount, type, description, reference_type, reference_id, idempotency_key)
       VALUES ($1, $2, 'withdrawal_hold', 'Wallet withdrawal pending review', 'withdrawal', $3, $4)`,
      [req.auth!.id, -amount, withdrawal.rows[0].id, `withdrawal-hold:${idempotencyKey}`],
    );
    await client.query('UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2', [amount, req.auth!.id]);
    await client.query('COMMIT');
    res.status(201).json({ data: withdrawal.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    next(error);
  } finally {
    client.release();
  }
});

router.post('/pay-booking', requireAuth, async (req: Request, res: Response) => {
  try {
    const bookingId = String(req.body?.bookingId ?? '');
    const idempotencyKey = String(req.body?.idempotencyKey ?? '');
    if (!bookingId || !idempotencyKey) return res.status(400).json({ error: 'bookingId and idempotencyKey are required.' });
    const result = await payBookingFromWallet(bookingId, req.auth!.id, idempotencyKey);
    res.status(201).json({ data: result });
  } catch (error: any) {
    res.status(400).json({ error: error.message || 'Wallet booking payment failed.' });
  }
});

export default router;