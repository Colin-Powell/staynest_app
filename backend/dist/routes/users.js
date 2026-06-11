import { Router } from 'express';
import { query, withAppUser } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
function ensureCurrentUserOrAdmin(req, userId) {
    const authUser = req.auth;
    if (!authUser) {
        return false;
    }
    return authUser.id === userId || authUser.role === 'admin';
}
router.get('/', async (_req, res, next) => {
    try {
        const result = await query(`SELECT id, name, email, role, avatar, verified, created_at
       FROM users
       ORDER BY name ASC`);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.get('/me', requireAuth, async (req, res, next) => {
    try {
        const result = await query(`SELECT id, name, email, phone, role, avatar, verified
       FROM users
       WHERE id = $1
       LIMIT 1`, [req.auth.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.put('/:id/fcm-token', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (!ensureCurrentUserOrAdmin(req, userId)) {
            return res.status(403).json({ error: 'Access denied.' });
        }
        const { fcmToken } = req.body;
        if (!fcmToken || !fcmToken.trim()) {
            return res.status(400).json({ error: 'fcmToken is required.' });
        }
        await query('ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token text');
        const result = await query('UPDATE users SET fcm_token = $1 WHERE id = $2 RETURNING id', [fcmToken.trim(), userId]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        return res.json({ data: { ok: true } });
    }
    catch (error) {
        next(error);
    }
});
router.patch('/me', requireAuth, async (req, res, next) => {
    try {
        const { name, email, phone, avatar } = req.body;
        const updates = [];
        const params = [];
        if (typeof name === 'string' && name.trim() !== '') {
            params.push(name.trim());
            updates.push(`name = $${params.length}`);
        }
        if (typeof email === 'string' && email.trim() !== '') {
            const normalizedEmail = email.trim().toLowerCase();
            const exists = await query('SELECT id FROM users WHERE email = $1 AND id != $2 LIMIT 1', [normalizedEmail, req.auth.id]);
            if ((exists.rowCount ?? 0) > 0) {
                return res.status(409).json({ error: 'Email already in use.' });
            }
            params.push(normalizedEmail);
            updates.push(`email = $${params.length}`);
        }
        if (typeof phone === 'string' && phone.trim() !== '') {
            params.push(phone.trim());
            updates.push(`phone = $${params.length}`);
        }
        if (typeof avatar === 'string' && avatar.trim() !== '') {
            params.push(avatar.trim());
            updates.push(`avatar = $${params.length}`);
        }
        if (updates.length === 0) {
            return res.status(400).json({ error: 'No profile fields provided for update.' });
        }
        params.push(req.auth.id);
        const result = await query(`UPDATE users
       SET ${updates.join(', ')}
       WHERE id = $${params.length}
       RETURNING id, name, email, phone, role, avatar, verified`, params);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        res.json({ data: { user: result.rows[0] } });
    }
    catch (error) {
        next(error);
    }
});
router.get('/:id', async (req, res, next) => {
    try {
        const result = await query(`SELECT id, name, email, phone, role, avatar, verified,
              business_name, business_description, years_in_business, created_at
       FROM users
       WHERE id = $1
       LIMIT 1`, [req.params.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        const propertyCount = await query('SELECT COUNT(*)::int AS count FROM properties WHERE landlord_id = $1', [req.params.id]);
        res.json({
            data: {
                ...result.rows[0],
                property_count: propertyCount.rows[0]?.count ?? 0,
            },
        });
    }
    catch (error) {
        next(error);
    }
});
router.get('/:id/properties', async (req, res, next) => {
    try {
        const userId = req.params.id;
        const result = await query(`SELECT p.id,
              p.title,
              p.description,
              p.category,
              p.city,
              p.address,
              p.price,
              p.bedrooms,
              p.bathrooms,
              p.area,
              p.image_url,
              p.images,
              p.amenities,
              p.lat,
              p.lng,
              u.id AS landlord_id,
              u.name AS landlord_name,
              u.email AS landlord_email,
              u.avatar AS landlord_avatar,
              u.verified AS landlord_verified
       FROM properties p
       LEFT JOIN users u ON u.id = p.landlord_id
       WHERE p.landlord_id = $1
       ORDER BY p.created_at DESC`, [userId]);
        const rows = result.rows.map((row) => {
            let images = row.images;
            if (!Array.isArray(images) || images.length === 0) {
                if (row.image_url)
                    row.images = [row.image_url];
            }
            return row;
        });
        res.json({ data: rows });
    }
    catch (error) {
        next(error);
    }
});
router.get('/:id/favorites', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (!ensureCurrentUserOrAdmin(req, userId)) {
            return res.status(403).json({ error: 'Access denied.' });
        }
        const result = await withAppUser(req.auth.id, async (client) => client.query(`SELECT p.id,
                p.title,
                p.description,
                p.category,
                p.city,
                p.price,
                p.bedrooms,
                p.bathrooms,
                p.area,
                p.image_url,
                u.id AS landlord_id,
                u.name AS landlord_name,
                u.email AS landlord_email,
                f.created_at AS saved_at
         FROM favorites f
         JOIN properties p ON p.id = f.property_id
         LEFT JOIN users u ON u.id = p.landlord_id
         WHERE f.user_id = $1
         ORDER BY f.created_at DESC`, [userId]));
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.post('/:id/favorites', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (!ensureCurrentUserOrAdmin(req, userId)) {
            return res.status(403).json({ error: 'Access denied.' });
        }
        const { propertyId } = req.body;
        if (!propertyId) {
            return res.status(400).json({ error: 'propertyId is required.' });
        }
        const propertyExists = await query('SELECT 1 FROM properties WHERE id = $1 LIMIT 1', [propertyId]);
        if (propertyExists.rowCount === 0) {
            return res.status(404).json({ error: 'Property not found.' });
        }
        await withAppUser(req.auth.id, async (client) => client.query(`INSERT INTO favorites (user_id, property_id)
         VALUES ($1, $2)
         ON CONFLICT (user_id, property_id) DO NOTHING`, [userId, propertyId]));
        res.status(201).json({ data: { saved: true } });
    }
    catch (error) {
        next(error);
    }
});
router.delete('/:id/favorites/:propertyId', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (!ensureCurrentUserOrAdmin(req, userId)) {
            return res.status(403).json({ error: 'Access denied.' });
        }
        const propertyId = req.params.propertyId;
        await withAppUser(req.auth.id, async (client) => client.query(`DELETE FROM favorites
         WHERE user_id = $1
           AND property_id = $2`, [userId, propertyId]));
        res.json({ data: { saved: false } });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=users.js.map