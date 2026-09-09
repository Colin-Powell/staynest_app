import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
const normalizePhone = (value) => {
    const digits = value.replace(/\D/g, '');
    if (!digits)
        return '';
    if (digits.startsWith('254'))
        return digits;
    if (digits.startsWith('0'))
        return `254${digits.slice(1)}`;
    return `254${digits}`;
};
const validatePhone = (phone) => {
    const normalized = normalizePhone(phone);
    return /^254[17]\d{8}$/.test(normalized);
};
const mapMethod = (row) => ({
    id: row.id,
    type: row.type,
    display_name: row.display_name,
    account_number: row.account_number,
    bank_name: row.bank_name ?? '',
    account_holder: row.account_holder ?? '',
    is_default: row.is_default,
    last_used: row.last_used,
    created_at: row.created_at,
});
router.get('/payment-methods', requireAuth, async (req, res, next) => {
    try {
        const result = await query(`SELECT *
       FROM landlord_payment_methods
       WHERE user_id = $1
       ORDER BY is_default DESC, created_at DESC`, [req.auth.id]);
        return res.json({ data: result.rows.map(mapMethod) });
    }
    catch (err) {
        next(err);
    }
});
router.post('/payment-methods', requireAuth, async (req, res, next) => {
    try {
        const type = String(req.body?.type ?? '').trim().toLowerCase();
        const rawAccount = typeof req.body?.account_number === 'string' ? req.body.account_number.trim() : '';
        const bankName = typeof req.body?.bank_name === 'string' ? req.body.bank_name.trim() : '';
        const accountHolder = typeof req.body?.account_holder === 'string' ? req.body.account_holder.trim() : '';
        const displayName = typeof req.body?.display_name === 'string' ? req.body.display_name.trim() : '';
        const isDefault = Boolean(req.body?.is_default);
        if (!['mpesa', 'bank_transfer', 'card'].includes(type)) {
            return res.status(400).json({ error: 'Unsupported payment method type.' });
        }
        if (!rawAccount) {
            return res.status(400).json({ error: 'account_number is required.' });
        }
        if (type === 'mpesa' && !validatePhone(rawAccount)) {
            return res.status(400).json({ error: 'Invalid M-Pesa phone number.' });
        }
        if (type === 'bank_transfer' && (!bankName || !accountHolder)) {
            return res.status(400).json({ error: 'bank_name and account_holder are required for bank transfers.' });
        }
        const normalizedPhone = type === 'mpesa' ? normalizePhone(rawAccount) : rawAccount;
        const accountNumber = type === 'mpesa' ? normalizedPhone : rawAccount;
        const finalDisplayName = displayName ||
            (type === 'mpesa'
                ? `M-Pesa - ${accountNumber.slice(-4)}`
                : `${bankName} - ${accountNumber.slice(-4)}`);
        try {
            await query('BEGIN');
            if (isDefault) {
                await query(`UPDATE landlord_payment_methods
           SET is_default = false
           WHERE user_id = $1`, [req.auth.id]);
            }
            const result = await query(`INSERT INTO landlord_payment_methods (
          user_id, type, display_name, account_number, bank_name, account_holder,
          is_default, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
        RETURNING *`, [
                req.auth.id,
                type,
                finalDisplayName,
                accountNumber,
                bankName,
                accountHolder,
                isDefault,
            ]);
            await query('COMMIT');
            return res.status(201).json({ data: mapMethod(result.rows[0]) });
        }
        catch (err) {
            await query('ROLLBACK');
            throw err;
        }
    }
    catch (err) {
        next(err);
    }
});
router.post('/payment-methods/:id/set-default', requireAuth, async (req, res, next) => {
    try {
        const methodId = req.params.id;
        const methodResult = await query(`SELECT id FROM landlord_payment_methods WHERE id = $1 AND user_id = $2 LIMIT 1`, [methodId, req.auth.id]);
        if (methodResult.rowCount === 0) {
            return res.status(404).json({ error: 'Payment method not found.' });
        }
        await query('BEGIN');
        try {
            await query(`UPDATE landlord_payment_methods
         SET is_default = false
         WHERE user_id = $1`, [req.auth.id]);
            await query(`UPDATE landlord_payment_methods
         SET is_default = true
         WHERE id = $1 AND user_id = $2`, [methodId, req.auth.id]);
            await query('COMMIT');
            return res.json({ ok: true });
        }
        catch (err) {
            await query('ROLLBACK');
            throw err;
        }
    }
    catch (err) {
        next(err);
    }
});
router.delete('/payment-methods/:id', requireAuth, async (req, res, next) => {
    try {
        const methodResult = await query(`SELECT id, is_default FROM landlord_payment_methods WHERE id = $1 AND user_id = $2 LIMIT 1`, [req.params.id, req.auth.id]);
        if (methodResult.rowCount === 0) {
            return res.status(404).json({ error: 'Payment method not found.' });
        }
        const method = methodResult.rows[0];
        if (method.is_default) {
            const otherResults = await query(`SELECT id FROM landlord_payment_methods WHERE user_id = $1 AND id != $2 LIMIT 1`, [req.auth.id, method.id]);
            if ((otherResults.rowCount ?? 0) > 0) {
                return res.status(400).json({ error: 'Set another default payment method before removing this one.' });
            }
        }
        await query(`DELETE FROM landlord_payment_methods WHERE id = $1 AND user_id = $2`, [req.params.id, req.auth.id]);
        return res.json({ ok: true });
    }
    catch (err) {
        next(err);
    }
});
export default router;
//# sourceMappingURL=landlord_payment_methods.js.map