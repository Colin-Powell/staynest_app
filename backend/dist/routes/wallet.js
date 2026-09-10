import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
router.get('/', requireAuth, async (req, res, next) => {
    try {
        const result = await query('SELECT wallet_balance, referral_code FROM users WHERE id = $1 LIMIT 1', [req.auth.id]);
        if (result.rowCount === 0)
            return res.status(404).json({ error: 'User not found.' });
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.get('/transactions', requireAuth, async (req, res, next) => {
    try {
        const result = await query(`SELECT id, amount, type, description, reference_type, reference_id, created_at
       FROM wallet_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 100`, [req.auth.id]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=wallet.js.map