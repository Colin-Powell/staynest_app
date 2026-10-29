import { Router } from 'express';
import { pool, query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import bcrypt from 'bcrypt';
import { routeCache } from '../middleware/cache.js';
import { cache } from '../services/cache.js';
const router = Router();
router.patch('/profile', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth?.id;
        const body = req.body ?? {};
        if (typeof body !== 'object' || Array.isArray(body)) {
            return res.status(400).json({ error: 'Profile updates must be an object.' });
        }
        if ('email' in body) {
            return res.status(400).json({ error: 'Email cannot be changed through profile updates.' });
        }
        const updates = [];
        const values = [];
        const addUpdate = (column, value) => {
            values.push(value);
            updates.push(`${column} = $${values.length}`);
        };
        if ('name' in body) {
            if (typeof body.name !== 'string' || !body.name.trim() || body.name.trim().length > 120) {
                return res.status(400).json({ error: 'Name must be between 1 and 120 characters.' });
            }
            addUpdate('name', body.name.trim());
        }
        if ('phone' in body) {
            if (body.phone !== null && typeof body.phone !== 'string') {
                return res.status(400).json({ error: 'Phone number must be text.' });
            }
            const phone = typeof body.phone === 'string' ? body.phone.trim() : '';
            if (phone && !/^[+0-9().\s-]{7,25}$/.test(phone)) {
                return res.status(400).json({ error: 'Enter a valid phone number.' });
            }
            addUpdate('phone', phone || null);
        }
        if ('avatar' in body) {
            if (typeof body.avatar !== 'string' || body.avatar.length > 500) {
                return res.status(400).json({ error: 'Avatar reference is invalid.' });
            }
            addUpdate('avatar', body.avatar.trim() || null);
        }
        const optionalFields = [
            ['businessName', 'business_name', 160],
            ['businessType', 'business_type', 100],
            ['businessDescription', 'business_description', 2000],
            ['taxId', 'tax_id', 100],
        ];
        for (const [input, column, maxLength] of optionalFields) {
            if (!(input in body))
                continue;
            const value = body[input];
            if (value !== null && (typeof value !== 'string' || value.length > maxLength)) {
                return res.status(400).json({ error: `${input} must be text of at most ${maxLength} characters.` });
            }
            addUpdate(column, typeof value === 'string' ? value.trim() || null : null);
        }
        if ('yearsInBusiness' in body) {
            const years = body.yearsInBusiness;
            if (years !== null && (!Number.isInteger(years) || years < 0 || years > 100)) {
                return res.status(400).json({ error: 'Years in business must be an integer from 0 to 100.' });
            }
            addUpdate('years_in_business', years);
        }
        if ('settings' in body) {
            if (!body.settings || typeof body.settings !== 'object' || Array.isArray(body.settings)) {
                return res.status(400).json({ error: 'Settings must be an object.' });
            }
            values.push(JSON.stringify(body.settings));
            updates.push(`settings = COALESCE(settings, '{}'::jsonb) || $${values.length}::jsonb`);
        }
        if (updates.length === 0) {
            return res.status(400).json({ error: 'No profile fields were provided.' });
        }
        const currentRes = 'avatar' in body
            ? await query('SELECT avatar FROM users WHERE id = $1', [userId])
            : null;
        const currentAvatar = currentRes?.rows[0]?.avatar;
        values.push(userId);
        const result = await query(`UPDATE users SET ${updates.join(', ')} WHERE id = $${values.length}
       RETURNING id, name, email, phone, avatar, role, roles, landlord_verified, verified, created_at,
                 business_name, business_type, business_description, tax_id, years_in_business, settings`, values);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        const nextAvatar = result.rows[0].avatar;
        if (currentAvatar && currentAvatar !== nextAvatar) {
            try {
                const { deleteFromCloudinary } = await import('../services/cloudinary.js');
                await deleteFromCloudinary(currentAvatar);
            }
            catch (_) {
                // The persisted profile remains valid if old-media cleanup fails.
            }
        }
        await cache.del('cache:/users*');
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.get('/recent-contacts', requireAuth, async (_req, res, next) => {
    try {
        // Placeholder response for the frontend's fetchRecentContacts call
        res.json({ data: { contacts: [] } });
    }
    catch (error) {
        next(error);
    }
});
router.get('/me', requireAuth, async (req, res, next) => {
    try {
        const result = await query(`SELECT id, name, email, phone, avatar, role, roles, landlord_verified, verified, created_at,
              business_name, business_type, business_description, tax_id,
              years_in_business, settings
       FROM users WHERE id = $1`, [req.auth?.id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
router.get('/:id', routeCache(3600), async (req, res, next) => {
    try {
        const { id } = req.params;
        const result = await query(`SELECT id, name, email, phone, avatar, role, verified, created_at, business_name, business_type, business_description, tax_id, years_in_business,
              (SELECT COUNT(*)::int
                 FROM properties p
                WHERE p.landlord_id = users.id
                  AND COALESCE(p.status, 'pending_review') = 'approved') AS property_count,
              (SELECT AVG(EXTRACT(EPOCH FROM (b.updated_at - b.created_at)))
                 FROM bookings b
                WHERE b.landlord_id = users.id
                  AND b.status IN ('confirmed', 'rejected')) AS response_time_seconds
       FROM users WHERE id = $1`, [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        const user = result.rows[0];
        // Strip sensitive fields if it's not the user's own profile
        if (req.auth?.id !== id) {
            delete user.email;
            delete user.phone;
            delete user.tax_id;
        }
        res.json({ data: user });
    }
    catch (error) {
        next(error);
    }
});
router.post('/change-password', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth?.id;
        const { currentPassword, newPassword } = req.body;
        const userRes = await query('SELECT password_hash FROM users WHERE id = $1', [userId]);
        const user = userRes.rows[0];
        const isMatch = await bcrypt.compare(currentPassword, user.password_hash);
        if (!isMatch)
            return res.status(400).json({ error: 'Incorrect current password' });
        const salt = await bcrypt.genSalt(10);
        const hash = await bcrypt.hash(newPassword, salt);
        await query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, userId]);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
router.put('/:id/fcm-token', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (req.auth?.id !== userId) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        const fcmToken = typeof req.body?.fcmToken === 'string' ? req.body.fcmToken.trim() : '';
        if (!fcmToken || fcmToken.length > 4096) {
            return res.status(400).json({ error: 'A valid fcmToken is required.' });
        }
        const notificationsAllowed = req.body?.notificationsAllowed;
        if (notificationsAllowed !== undefined && typeof notificationsAllowed !== 'boolean') {
            return res.status(400).json({ error: 'notificationsAllowed must be a boolean.' });
        }
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            await client.query('UPDATE users SET fcm_token = NULL WHERE fcm_token = $1 AND id <> $2', [fcmToken, userId]);
            await client.query(`UPDATE users
         SET fcm_token = $1,
             settings = CASE WHEN $3::boolean IS NULL THEN COALESCE(settings, '{}'::jsonb)
               ELSE COALESCE(settings, '{}'::jsonb) || jsonb_build_object('push_permission_granted', $3::boolean)
             END
         WHERE id = $2`, [fcmToken, userId, typeof notificationsAllowed === 'boolean' ? notificationsAllowed : null]);
            await client.query('COMMIT');
        }
        catch (error) {
            await client.query('ROLLBACK').catch(() => undefined);
            throw error;
        }
        finally {
            client.release();
        }
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
router.delete('/:id/fcm-token', requireAuth, async (req, res, next) => {
    try {
        if (req.auth?.id !== req.params.id) {
            return res.status(403).json({ error: 'Forbidden' });
        }
        await query('UPDATE users SET fcm_token = NULL WHERE id = $1', [req.params.id]);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
router.get('/:id/favorites', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (req.auth?.id !== userId)
            return res.status(403).json({ error: 'Forbidden' });
        const result = await query(`SELECT property_id FROM favorites WHERE user_id = $1`, [userId]);
        res.json({ data: result.rows });
    }
    catch (error) {
        next(error);
    }
});
router.post('/:id/favorites', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        if (req.auth?.id !== userId)
            return res.status(403).json({ error: 'Forbidden' });
        const { propertyId } = req.body;
        if (!propertyId)
            return res.status(400).json({ error: 'propertyId is required' });
        await query(`INSERT INTO favorites (user_id, property_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, propertyId]);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
router.delete('/:id/favorites/:propertyId', requireAuth, async (req, res, next) => {
    try {
        const userId = req.params.id;
        const { propertyId } = req.params;
        if (req.auth?.id !== userId)
            return res.status(403).json({ error: 'Forbidden' });
        await query(`DELETE FROM favorites WHERE user_id = $1 AND property_id = $2`, [userId, propertyId]);
        res.json({ ok: true });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=users.js.map