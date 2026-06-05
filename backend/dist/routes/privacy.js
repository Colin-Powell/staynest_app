import { Router } from 'express';
import fs from 'fs/promises';
import path from 'path';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
// Serve a static privacy policy file (markdown or text) if present
router.get('/', async (_req, res, next) => {
    try {
        const policyPath = path.resolve(process.cwd(), 'PRIVACY.md');
        try {
            const text = await fs.readFile(policyPath, 'utf8');
            return res.json({ data: { policy: text } });
        }
        catch (_err) {
            // Fallback policy
            const fallback = `Privacy & Data Retention Policy:\n\nWe collect minimal personal information to provide personalized recommendations and manage bookings. Users may opt-in to personalized recommendations. Requests to delete account data can be submitted and will be processed within 30 days.`;
            return res.json({ data: { policy: fallback } });
        }
    }
    catch (error) {
        next(error);
    }
});
// Allow authenticated users to submit a data deletion request
router.post('/delete-request', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        const reason = typeof req.body.reason === 'string' ? req.body.reason.trim() : null;
        const result = await query(`INSERT INTO deletion_requests (user_id, reason, status)
       VALUES ($1, $2, 'pending')
       RETURNING id, user_id, reason, status, created_at`, [userId, reason]);
        res.status(201).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=privacy.js.map