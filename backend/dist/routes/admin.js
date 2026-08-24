import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
import { sendPushToTopic } from '../services/firebase.js';
const router = Router();
async function ensurePropertyStatusColumn() {
    await query(`ALTER TABLE properties ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending_review'`);
}
router.get('/overview', requireAuth, authorize('admin'), async (_req, res, next) => {
    try {
        const [usersRes, propertiesRes, verificationsRes, bookingsRes] = await Promise.all([
            query(`SELECT COUNT(*)::int AS count FROM users`),
            query(`SELECT COUNT(*)::int AS count FROM properties`),
            query(`SELECT COUNT(*)::int AS count FROM verifications WHERE status = 'submitted'`),
            query(`SELECT COUNT(*)::int AS count FROM bookings`),
        ]);
        const revenueRes = await query(`SELECT COALESCE(SUM(total_price), 0)::numeric AS total FROM bookings WHERE status IN ('confirmed', 'completed')`);
        res.json({
            data: {
                users: usersRes.rows[0]?.count ?? 0,
                properties: propertiesRes.rows[0]?.count ?? 0,
                pendingKyc: verificationsRes.rows[0]?.count ?? 0,
                bookings: bookingsRes.rows[0]?.count ?? 0,
                revenue: Number(revenueRes.rows[0]?.total ?? 0),
            },
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/users', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 10, 50);
        const result = await query(`SELECT id, name, email, role, verified, created_at FROM users ORDER BY created_at DESC LIMIT $1`, [limit]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.get('/properties', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        await ensurePropertyStatusColumn();
        const limit = Math.min(parseInt(req.query.limit) || 10, 50);
        const result = await query(`SELECT p.id, p.title, p.city, p.price, p.created_at, u.name AS landlord_name, p.image_url, COALESCE(p.status, 'pending_review') AS status
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       ORDER BY p.created_at DESC LIMIT $1`, [limit]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.patch('/properties/:id/status', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        await ensurePropertyStatusColumn();
        const { status } = req.body;
        if (!status || !['approved', 'rejected', 'pending_review'].includes(status)) {
            return res.status(400).json({ error: 'Status must be one of approved, rejected, or pending_review.' });
        }
        const result = await query(`UPDATE properties SET status = $1 WHERE id = $2 RETURNING id, title, status`, [status, req.params.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Property not found.' });
        }
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.get('/kyc', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 10, 50);
        const result = await query(`SELECT v.id, v.status, v.created_at, u.name, u.email
       FROM verifications v
       LEFT JOIN users u ON u.id = v.user_id
       ORDER BY v.created_at DESC LIMIT $1`, [limit]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.patch('/kyc/:id', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const { status, admin_notes } = req.body;
        if (!status || !['approved', 'rejected'].includes(status)) {
            return res.status(400).json({ error: 'Status must be approved or rejected.' });
        }
        const result = await query(`UPDATE verifications
       SET status = $1, admin_notes = $2, updated_at = now()
       WHERE id = $3
       RETURNING id, user_id, status, admin_notes, created_at, updated_at`, [status, admin_notes ?? null, req.params.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'Verification not found.' });
        }
        const verification = result.rows[0];
        await query(`UPDATE users SET verified = $1 WHERE id = $2`, [status === 'approved', verification.user_id]);
        res.json({ data: verification });
    }
    catch (error) {
        next(error);
    }
});
// Broadcast a general alert to all users (topic: 'alerts')
router.post('/broadcast-alert', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const { title, body, data } = req.body;
        if (!title || !body)
            return res.status(400).json({ error: 'title and body are required' });
        await sendPushToTopic('alerts', title, body, data);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
// Broadcast trending properties alert to all users (topic: 'trending')
router.post('/broadcast-trending', requireAuth, authorize('admin'), async (req, res, next) => {
    try {
        const { title, body, data } = req.body;
        // In a real scenario, this could query the DB for the top booked/viewed properties and construct the message automatically.
        // For now, it allows the admin to supply the message or fallback to a default.
        const alertTitle = title || 'Trending Properties 🔥';
        const alertBody = body || 'Check out the most popular properties this week on StayNest!';
        await sendPushToTopic('trending', alertTitle, alertBody, data);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=admin.js.map