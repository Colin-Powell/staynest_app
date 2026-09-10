import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { initiateSTKPush, parseCallback, verifyCallbackSignature } from '../services/mpesa.js';
import { cache } from '../services/cache.js';
import { settleWalletTopup } from '../services/finance_service.js';
const router = Router();
/**
 * Initiate M-Pesa STKPush for boost payment
 * POST /api/payments/boost-initiate
 */
router.post('/boost-initiate', requireAuth, async (req, res, next) => {
    try {
        const { propertyId, packageType, phone } = req.body;
        if (!propertyId || !packageType) {
            return res.status(400).json({ error: 'propertyId and packageType are required' });
        }
        if (!phone) {
            return res.status(400).json({ error: 'phone is required for M-Pesa payment' });
        }
        // Verify property ownership
        const propResult = await query('SELECT landlord_id, title FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        if (propResult.rowCount === 0) {
            return res.status(404).json({ error: 'Property not found' });
        }
        const property = propResult.rows[0];
        if (property.landlord_id !== req.auth.id) {
            return res.status(403).json({ error: 'Not authorized to boost this property' });
        }
        // Define boost packages
        const BOOST_PACKAGES = {
            basic: { amount: 1500, days: 7, boost_score: 50 },
            premium: { amount: 2500, days: 14, boost_score: 150 },
            elite: { amount: 5000, days: 30, boost_score: 500 },
        };
        if (!BOOST_PACKAGES[packageType]) {
            return res.status(400).json({ error: 'Invalid package type' });
        }
        const pkg = BOOST_PACKAGES[packageType];
        const reference = `${propertyId.substring(0, 12)}-${Date.now()}`.substring(0, 12);
        // Initiate M-Pesa STKPush
        let stkResponse;
        try {
            stkResponse = await initiateSTKPush({
                phone,
                amount: pkg.amount,
                reference,
                description: `Boost ${property.title}`,
                email: req.auth.email,
            });
        }
        catch (err) {
            console.error('[Payment] STKPush error:', err.message);
            return res.status(400).json({ error: 'Failed to initiate M-Pesa payment' });
        }
        // Create a pending payment transaction record
        const txnResult = await query(`INSERT INTO payment_transactions (
        promotion_id, user_id, transaction_type, amount, currency,
        payment_method, status, checkout_request_id, created_at
      ) VALUES (
        NULL, $1, $2, $3, $4, $5, $6, $7, NOW()
      ) RETURNING id`, [
            req.auth.id,
            'boost',
            pkg.amount,
            'KES',
            'mpesa',
            'processing',
            stkResponse.CheckoutRequestID,
        ]);
        return res.json({
            checkoutRequestId: stkResponse.CheckoutRequestID,
            merchantRequestId: stkResponse.MerchantRequestID,
            responseCode: stkResponse.ResponseCode,
            responseDescription: stkResponse.ResponseDescription,
            transactionId: txnResult.rows[0].id,
        });
    }
    catch (err) {
        next(err);
    }
});
/**
 * Handle M-Pesa STKPush callback
 * POST /api/payments/mpesa-callback
 */
router.post('/mpesa-callback', async (req, res, next) => {
    try {
        const callbackData = req.body;
        if (!callbackData || !callbackData.Body || !callbackData.Body.stkCallback) {
            return res.status(400).json({ error: 'Invalid callback data' });
        }
        // Verify callback signature (basic check - enhance in production)
        if (!verifyCallbackSignature(callbackData)) {
            return res.status(400).json({ error: 'Invalid callback signature' });
        }
        const result = parseCallback(callbackData);
        const checkoutRequestId = result.checkoutRequestId;
        // Find the payment transaction
        const txnResult = await query(`SELECT id, promotion_id, user_id, amount, status, transaction_type FROM payment_transactions
       WHERE checkout_request_id = $1 LIMIT 1`, [checkoutRequestId]);
        if (!txnResult.rowCount || txnResult.rowCount === 0) {
            console.warn('[Payment] Callback for unknown transaction:', checkoutRequestId);
            return res.status(404).json({ error: 'Transaction not found' });
        }
        const transaction = txnResult.rows[0];
        if (transaction.status === 'completed') {
            return res.json({ ResultCode: 0, ResultDesc: 'Already processed' });
        }
        if (result.success && result.amount != null && Number(result.amount) !== Number(transaction.amount)) {
            await query(`UPDATE payment_transactions SET status = 'failed', error_message = $1, completed_at = NOW()
         WHERE id = $2 AND status <> 'completed'`, ['Callback amount does not match transaction amount.', transaction.id]);
            return res.status(400).json({ error: 'Payment amount mismatch.' });
        }
        await query('BEGIN');
        try {
            if (result.success) {
                // Payment successful - update transaction
                await query(`UPDATE payment_transactions SET
            status = 'completed',
            mpesa_receipt_number = $1,
            mpesa_transaction_id = $2,
            completed_at = NOW()
           WHERE checkout_request_id = $3`, [result.mpesaReceiptNumber, result.mpesaReceiptNumber, checkoutRequestId]);
                if (transaction.transaction_type === 'wallet_topup') {
                    await query('COMMIT');
                    await settleWalletTopup(transaction.id);
                    return res.json({
                        ResultCode: 0,
                        ResultDesc: 'Wallet top-up processed successfully',
                    });
                }
                // Check if this is for a promotion (boost)
                // Find unprocessed promotion for this user with pending payment
                const promoResult = await query(`SELECT id, property_id, landlord_id, package_type, boost_score, amount,
                  start_date, end_date
           FROM promotion_campaigns
           WHERE landlord_id = $1 AND payment_status = 'pending'
           ORDER BY created_at DESC LIMIT 1`, [transaction.user_id]);
                if (promoResult.rowCount && promoResult.rowCount > 0) {
                    const promo = promoResult.rows[0];
                    // Update promotion with payment info
                    await query(`UPDATE promotion_campaigns SET
              payment_status = 'completed',
              checkout_request_id = $1,
              mpesa_receipt_number = $2,
              payment_date = NOW()
             WHERE id = $3`, [checkoutRequestId, result.mpesaReceiptNumber, promo.id]);
                    // Activate the promotion
                    await query(`UPDATE promotion_campaigns SET active = true
             WHERE id = $1`, [promo.id]);
                    // Invalidate property feed cache to reflect new boost
                    await cache.del(`cache:properties.*`);
                }
                await query('COMMIT');
                return res.json({
                    ResultCode: 0,
                    ResultDesc: 'Payment processed successfully',
                });
            }
            else {
                // Payment failed
                await query(`UPDATE payment_transactions SET
            status = 'failed',
            error_message = $1,
            completed_at = NOW()
           WHERE checkout_request_id = $2`, [result.resultDesc, checkoutRequestId]);
                await query('COMMIT');
                return res.json({
                    ResultCode: result.resultCode,
                    ResultDesc: result.resultDesc,
                });
            }
        }
        catch (dbErr) {
            await query('ROLLBACK');
            throw dbErr;
        }
    }
    catch (err) {
        console.error('[Payment] Callback error:', err);
        next(err);
    }
});
router.post('/mpesa-b2c-callback', async (req, res, next) => {
    try {
        const result = req.body?.Result;
        const conversationId = result?.ConversationID;
        const resultCode = Number(result?.ResultCode);
        if (!conversationId || !Number.isFinite(resultCode)) {
            return res.status(400).json({ error: 'Invalid B2C callback.' });
        }
        const withdrawal = await query(`SELECT id, user_id, amount FROM wallet_withdrawals
       WHERE provider_reference = $1 AND status = 'processing' FOR UPDATE`, [conversationId]);
        if (withdrawal.rows.length === 0)
            return res.status(404).json({ error: 'Withdrawal not found.' });
        const row = withdrawal.rows[0];
        if (resultCode === 0) {
            await query(`UPDATE wallet_withdrawals SET status = 'paid', processed_at = NOW(), released_at = NOW()
         WHERE id = $1`, [row.id]);
        }
        else {
            await query('BEGIN');
            try {
                await query(`UPDATE wallet_withdrawals SET status = 'failed', failure_reason = $1, processed_at = NOW()
           WHERE id = $2`, [result.ResultDesc || 'M-Pesa payout failed.', row.id]);
                const refundEntry = await query(`INSERT INTO wallet_transactions
           (user_id, amount, type, description, reference_type, reference_id, idempotency_key)
           VALUES ($1, $2, 'withdrawal_refund', 'Failed withdrawal returned to wallet', 'withdrawal', $3, $4)
           ON CONFLICT (idempotency_key) DO NOTHING`, [row.user_id, row.amount, row.id, `withdrawal-refund:${row.id}`]);
                if (refundEntry.rows.length > 0) {
                    await query('UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2', [row.amount, row.user_id]);
                }
                await query('COMMIT');
            }
            catch (error) {
                await query('ROLLBACK');
                throw error;
            }
        }
        res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
    }
    catch (error) {
        next(error);
    }
});
/**
 * Get payment transaction status
 * GET /api/payments/status/:transactionId
 */
router.get('/status/:transactionId', requireAuth, async (req, res, next) => {
    try {
        const { transactionId } = req.params;
        const result = await query(`SELECT id, status, amount, currency, payment_method, error_message,
              created_at, completed_at, mpesa_receipt_number
       FROM payment_transactions
       WHERE id = $1 AND user_id = $2 LIMIT 1`, [transactionId, req.auth.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Transaction not found' });
        }
        return res.json(result.rows[0]);
    }
    catch (err) {
        next(err);
    }
});
/**
 * Get user's payment transactions
 * GET /api/payments/history
 */
router.get('/history', requireAuth, async (req, res, next) => {
    try {
        const result = await query(`SELECT id, transaction_type, amount, currency, status, payment_method,
              created_at, completed_at, mpesa_receipt_number
       FROM payment_transactions
       WHERE user_id = $1
       ORDER BY created_at DESC
       LIMIT 50`, [req.auth.id]);
        return res.json(result.rows);
    }
    catch (err) {
        next(err);
    }
});
export default router;
//# sourceMappingURL=payments.js.map