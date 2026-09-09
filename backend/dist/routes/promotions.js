import { Router } from 'express';
import { pool, query } from '../db.js';
import { authorize, requireAuth } from '../middleware/auth.js';
import { cache } from '../services/cache.js';
const router = Router();
const BOOST_PACKAGES = {
    basic: { days: 7, boostScore: 50, amount: 1500 },
    premium: { days: 14, boostScore: 150, amount: 2500 },
    elite: { days: 30, boostScore: 500, amount: 5000 },
};
router.post('/boost', requireAuth, authorize('landlord', 'host'), async (req, res) => {
    const propertyId = typeof req.body?.property_id === 'string' ? req.body.property_id.trim() : '';
    const packageType = typeof req.body?.package_type === 'string' ? req.body.package_type.trim().toLowerCase() : '';
    const idempotencyKey = typeof req.body?.idempotency_key === 'string'
        ? req.body.idempotency_key.trim()
        : '';
    const packageConfig = BOOST_PACKAGES[packageType];
    if (!propertyId || !packageConfig || !idempotencyKey || idempotencyKey.length > 128) {
        return res.status(400).json({ error: 'property_id, package_type, and a valid idempotency_key are required.' });
    }
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const existing = await client.query(`SELECT * FROM promotion_campaigns
       WHERE landlord_id = $1 AND idempotency_key = $2
       LIMIT 1`, [req.auth.id, idempotencyKey]);
        if (existing.rows.length > 0) {
            await client.query('COMMIT');
            return res.json({ data: existing.rows[0], idempotent: true });
        }
        const property = await client.query(`SELECT id FROM properties
       WHERE id = $1 AND landlord_id = $2 AND status = 'approved'
       FOR UPDATE`, [propertyId, req.auth.id]);
        if (property.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ error: 'Approved property not found for this landlord.' });
        }
        const overlapping = await client.query(`SELECT id FROM promotion_campaigns
       WHERE property_id = $1 AND active = true
         AND start_date < NOW() + ($2 * INTERVAL '1 day')
         AND end_date > NOW()
       LIMIT 1`, [propertyId, packageConfig.days]);
        if (overlapping.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(409).json({ error: 'This property already has an active promotion.' });
        }
        const created = await client.query(`INSERT INTO promotion_campaigns
         (property_id, landlord_id, package_type, boost_score, amount, currency, idempotency_key, start_date, end_date, active)
       VALUES ($1, $2, $3, $4, $5, 'KES', $6, NOW(), NOW() + ($7 * INTERVAL '1 day'), true)
       RETURNING *`, [propertyId, req.auth.id, packageType, packageConfig.boostScore, packageConfig.amount, idempotencyKey, packageConfig.days]);
        await client.query('COMMIT');
        await cache.del('cache:properties.*');
        return res.status(201).json({ data: created.rows[0] });
    }
    catch (error) {
        await client.query('ROLLBACK');
        if (error?.code === '23505') {
            return res.status(409).json({ error: 'This boost request has already been processed.' });
        }
        console.error('[Promotions] Failed to create boost:', error);
        return res.status(500).json({ error: 'Failed to create promotion.' });
    }
    finally {
        client.release();
    }
});
router.get('/relevant', requireAuth, async (_req, res) => {
    try {
        const result = await query('SELECT * FROM promotions WHERE active = true ORDER BY created_at DESC LIMIT 1');
        // If no promotions, just send a dummy one for testing the UI
        if (result.rows.length === 0) {
            return res.json({ data: [{
                        id: 'promo-1',
                        title: 'Discount on Beach Villas',
                        description: 'Get 20% off your first beach villa booking.',
                        image_url: 'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'
                    }] });
        }
        return res.json({ data: result.rows });
    }
    catch (err) {
        return res.status(500).json({ error: 'Failed' });
    }
});
router.get('/me', requireAuth, async (req, res) => {
    try {
        const result = await query(`SELECT pc.*, p.title, p.image_url
       FROM promotion_campaigns pc
       JOIN properties p ON p.id = pc.property_id
       WHERE pc.landlord_id = $1
         AND pc.active = true
         AND pc.end_date > NOW()
       ORDER BY pc.end_date ASC`, [req.auth?.id]);
        return res.json({ data: result.rows });
    }
    catch (err) {
        console.error('[Promotions] Failed to fetch landlord promotions:', err);
        return res.status(500).json({ error: 'Failed to fetch promotions.' });
    }
});
export default router;
//# sourceMappingURL=promotions.js.map