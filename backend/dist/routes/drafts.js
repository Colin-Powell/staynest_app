import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth, authorize } from '../middleware/auth.js';
const router = Router();
function nullableNumber(value) {
    if (value === null || value === undefined || value === '')
        return null;
    if (typeof value === 'string' && value.trim() === '')
        return null;
    const parsed = typeof value === 'number' ? value : Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}
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
        const { title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, service_charges, security_deposit, minimum_stay, available_from, custom_feature_input, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url, viewing_fee_type, viewing_fee_amount, viewing_fee_collector, viewing_fee_notes } = req.body;
        const result = await query(`INSERT INTO property_drafts 
        (landlord_id, title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, service_charges, security_deposit, minimum_stay, available_from, custom_feature_input, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url, viewing_fee_type, viewing_fee_amount, viewing_fee_collector, viewing_fee_notes)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33)
       RETURNING *`, [req.auth?.id, title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, nullableNumber(price), nullableNumber(service_charges), nullableNumber(security_deposit), minimum_stay || null, available_from || null, custom_feature_input || null, nullableNumber(bedrooms), nullableNumber(bathrooms), nullableNumber(area), JSON.stringify(amenities || []), nullableNumber(lat), nullableNumber(lng), JSON.stringify(photos || []), video_url || null, viewing_fee_type || 'unspecified', nullableNumber(viewing_fee_amount), viewing_fee_collector || null, viewing_fee_notes || null]);
        res.status(201).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// PUT update draft
router.put('/:id', requireAuth, authorize('landlord', 'host'), async (req, res, next) => {
    try {
        const { title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, price, service_charges, security_deposit, minimum_stay, available_from, custom_feature_input, bedrooms, bathrooms, area, amenities, lat, lng, photos, video_url, viewing_fee_type, viewing_fee_amount, viewing_fee_collector, viewing_fee_notes } = req.body;
        const result = await query(`UPDATE property_drafts SET 
        title = $1, description = $2, category = $3, city = $4, address = $5, country = $6, county = $7, sub_county = $8, ward = $9, town = $10, neighborhood = $11, estate_village = $12, road = $13, landmark = $14, price = $15,
        service_charges = $16, security_deposit = $17, minimum_stay = $18, available_from = $19, custom_feature_input = $20,
        bedrooms = $21, bathrooms = $22, area = $23, amenities = $24, lat = $25, lng = $26,
           photos = $27, video_url = $28, viewing_fee_type = $29,
           viewing_fee_amount = $30, viewing_fee_collector = $31,
           viewing_fee_notes = $32, updated_at = now()
             WHERE id = $33 AND landlord_id = $34
       RETURNING *`, [title, description, category, city, address, country, county, sub_county, ward, town, neighborhood, estate_village, road, landmark, nullableNumber(price), nullableNumber(service_charges), nullableNumber(security_deposit), minimum_stay || null, available_from || null, custom_feature_input || null, nullableNumber(bedrooms), nullableNumber(bathrooms), nullableNumber(area), JSON.stringify(amenities || []), nullableNumber(lat), nullableNumber(lng), JSON.stringify(photos || []), video_url || null, viewing_fee_type || 'unspecified', nullableNumber(viewing_fee_amount), viewing_fee_collector || null, viewing_fee_notes || null, req.params.id, req.auth?.id]);
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