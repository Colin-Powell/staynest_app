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
        const { title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url } = req.body;
        const result = await query(`INSERT INTO property_drafts 
        (landlord_id, title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24)
       RETURNING *`, [req.auth?.id, title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, bedrooms, bathrooms, area, JSON.stringify(amenities || []), lat, lng, JSON.stringify(photos || []), video_url || null]);
        res.status(201).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// PUT update draft
router.put('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url } = req.body;
        const result = await query(`UPDATE property_drafts SET 
        title = $1, description = $2, category = $3, city = $4, address = $5, country = $6, county = $7, sub_county = $8, ward = $9, town = $10, neighborhood = $11, estate_village = $12, road = $13, landmark = $14, price = $15,
        bedrooms = $16, bathrooms = $17, area = $18, amenities = $19, lat = $20, lng = $21,
        photos = $22, video_url = $23, updated_at = now()
             WHERE id = $24 AND landlord_id = $25
       RETURNING *`, [title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, bedrooms, bathrooms, area, JSON.stringify(amenities || []), lat, lng, JSON.stringify(photos || []), video_url || null, req.params.id, req.auth?.id]);
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