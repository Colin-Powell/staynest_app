import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
router.post('/promotion-open', requireAuth, async (req, res, next) => {
    try {
        const campaignId = String(req.body?.campaignId ?? '');
        const propertyId = String(req.body?.propertyId ?? '');
        const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
        if (!uuidPattern.test(campaignId) || !uuidPattern.test(propertyId)) {
            return res.status(400).json({ error: 'A valid campaign and property are required.' });
        }
        const result = await query(`UPDATE promotional_push_deliveries d
       SET opened_at = COALESCE(d.opened_at, now()), updated_at = now()
       FROM promotional_push_campaigns c
       WHERE d.campaign_id = c.id AND d.campaign_id = $1
         AND d.user_id = $2 AND c.property_id = $3
       RETURNING d.id`, [campaignId, req.auth.id, propertyId]);
        if (result.rows.length === 0)
            return res.status(404).json({ error: 'Campaign interaction not found.' });
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
// GET /api/notifications
router.get('/', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        const limit = parseInt(req.query.limit) || 50;
        const offset = parseInt(req.query.offset) || 0;
        const result = await query(`SELECT id, title, body, data, is_read, created_at 
       FROM notifications 
       WHERE user_id = $1 
       ORDER BY created_at DESC 
       LIMIT $2 OFFSET $3`, [userId, limit, offset]);
        const unreadCountRes = await query(`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`, [userId]);
        const unreadCount = parseInt(unreadCountRes.rows[0].count);
        res.json({
            data: result.rows,
            meta: { unreadCount }
        });
    }
    catch (error) {
        next(error);
    }
});
// PUT /api/notifications/:id/read
router.put('/:id/read', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        const notifId = req.params.id;
        const result = await query(`UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING id`, [notifId, userId]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Notification not found' });
        }
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
// PUT /api/notifications/read-all
router.put('/read-all', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        await query(`UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`, [userId]);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=notifications.js.map