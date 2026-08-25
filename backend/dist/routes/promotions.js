import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
const router = Router();
// Package definitions
const PACKAGES = {
    basic: { boost_score: 50, days: 7 },
    premium: { boost_score: 150, days: 14 },
    elite: { boost_score: 500, days: 30 },
};
// POST /api/promotions/boost - Purchase a boost for a property
router.post('/boost', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { property_id, package_type } = req.body;
        const landlord_id = req.auth?.id;
        if (!property_id || !package_type) {
            return res.status(400).json({ success: false, error: 'Property ID and package type are required.' });
        }
        const pkg = PACKAGES[package_type.toLowerCase()];
        if (!pkg) {
            return res.status(400).json({ success: false, error: 'Invalid package type.' });
        }
        // Verify ownership
        const propCheck = await query('SELECT id FROM properties WHERE id = $1 AND landlord_id = $2', [property_id, landlord_id]);
        if (propCheck.rowCount === 0) {
            return res.status(403).json({ success: false, error: 'Property not found or access denied.' });
        }
        // Terminate any existing active promotions for this property to avoid stacking issues
        await query(`UPDATE promotion_campaigns SET active = false WHERE property_id = $1`, [property_id]);
        // Create new promotion
        const result = await query(`INSERT INTO promotion_campaigns (property_id, landlord_id, package_type, boost_score, start_date, end_date, active)
       VALUES ($1, $2, $3, $4, NOW(), NOW() + interval '1 day' * $5, true)
       RETURNING *`, [property_id, landlord_id, package_type.toLowerCase(), pkg.boost_score, pkg.days]);
        res.status(201).json({ success: true, data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// GET /api/promotions/me - Get my active promotions
router.get('/me', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const landlord_id = req.auth?.id;
        const result = await query(`SELECT * FROM promotion_campaigns 
       WHERE landlord_id = $1 AND active = true AND end_date > NOW()
       ORDER BY created_at DESC`, [landlord_id]);
        res.json({ success: true, data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=promotions.js.map