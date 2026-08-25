import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
const router = Router();
// GET all drafts for landlord
router.get('/', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const result = await query(`SELECT * FROM property_drafts WHERE landlord_id = $1 ORDER BY updated_at DESC`, [req.auth?.id]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
// GET single draft
router.get('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const result = await query(`SELECT * FROM property_drafts WHERE id = $1 AND landlord_id = $2 LIMIT 1`, [req.params.id, req.auth?.id]);
        if (result.rowCount === 0)
            return res.status(404).json({ error: 'Draft not found.' });
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// POST create draft
router.post('/', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { title, description, category, city, address, price, bedrooms, bathrooms, area, amenities, lat, lng, photos } = req.body;
        const result = await query(`INSERT INTO property_drafts 
        (landlord_id, title, description, category, city, address, price, bedrooms, bathrooms, area, amenities, lat, lng, photos)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING *`, [req.auth?.id, title, description, category, city, address, price, bedrooms, bathrooms, area, JSON.stringify(amenities || []), lat, lng, JSON.stringify(photos || [])]);
        res.status(201).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// PUT update draft
router.put('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { title, description, category, city, address, price, bedrooms, bathrooms, area, amenities, lat, lng, photos } = req.body;
        const result = await query(`UPDATE property_drafts SET 
        title = $1, description = $2, category = $3, city = $4, address = $5, price = $6, 
        bedrooms = $7, bathrooms = $8, area = $9, amenities = $10, lat = $11, lng = $12, 
        photos = $13, updated_at = now()
       WHERE id = $14 AND landlord_id = $15
       RETURNING *`, [title, description, category, city, address, price, bedrooms, bathrooms, area, JSON.stringify(amenities || []), lat, lng, JSON.stringify(photos || []), req.params.id, req.auth?.id]);
        if (result.rowCount === 0)
            return res.status(404).json({ error: 'Draft not found.' });
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// DELETE draft
router.delete('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const result = await query(`DELETE FROM property_drafts WHERE id = $1 AND landlord_id = $2 RETURNING id`, [req.params.id, req.auth?.id]);
        if (result.rowCount === 0)
            return res.status(404).json({ error: 'Draft not found.' });
        res.json({ data: { deleted: true } });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=drafts.js.map