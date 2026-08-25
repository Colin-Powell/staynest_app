import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import bcrypt from 'bcrypt';
import { routeCache } from '../middleware/cache.js';
import { cache } from '../services/cache.js';

const router = Router();

router.patch('/profile', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth?.id;
    const {
      name, email, phone, avatar,
      businessName, businessType, businessDescription,
      taxId, yearsInBusiness,
      settings
    } = req.body;

    // If avatar is being updated, delete the old Cloudinary asset.
    // We store `users.avatar` as Cloudinary `public_id` (per client choice B).
    if (avatar != null) {
      // Fetch current avatar public_id
      const currentRes = await query('SELECT avatar FROM users WHERE id = $1', [userId]);
      const currentAvatar = currentRes.rows[0]?.avatar as string | null;

      if (currentAvatar && typeof currentAvatar === 'string' && currentAvatar !== avatar) {
        try {
          const { deleteFromCloudinary } = await import('../services/cloudinary.js');
          await deleteFromCloudinary(currentAvatar);
        } catch (_) {
          // Ignore deletion errors so profile update still succeeds.
        }

      }
    }

    const result = await query(
      `UPDATE users
         SET name = COALESCE(NULLIF($1, ''), name),
           email = COALESCE(NULLIF($2, ''), email),
           phone = COALESCE($3, phone),
           avatar = COALESCE($4, avatar),
           business_name = COALESCE($5, business_name),
           business_type = COALESCE($6, business_type),
           business_description = COALESCE($7, business_description),
           tax_id = COALESCE($8, tax_id),
           years_in_business = COALESCE($9, years_in_business),
           settings = COALESCE($10, settings)
         WHERE id = $11
       RETURNING id, name, email, phone, avatar, role, verified, created_at, business_name, business_type, business_description, tax_id, years_in_business, settings`,
      [
        name, email, phone, avatar,
        businessName, businessType, businessDescription,
        taxId, yearsInBusiness,
        settings ? JSON.stringify(settings) : null,
        userId
      ]
    );

    await cache.del('cache:/users*');
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.get('/recent-contacts', requireAuth, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    // Placeholder response for the frontend's fetchRecentContacts call
    res.json({ data: { contacts: [] } });
  } catch (error) {
    next(error);
  }
});

router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT id, name, email, phone, avatar, role, verified, created_at,
              business_name, business_type, business_description, tax_id,
              years_in_business, settings
       FROM users WHERE id = $1`,
      [req.auth?.id],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

router.get('/:id', routeCache(3600), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const result = await query(
      `SELECT id, name, email, phone, avatar, role, verified, created_at, business_name, business_type, business_description, tax_id, years_in_business
       FROM users WHERE id = $1`,
      [id]
    );

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
  } catch (error) {
    next(error);
  }
});


router.post('/change-password', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth?.id;
    const { currentPassword, newPassword } = req.body;

    const userRes = await query('SELECT password_hash FROM users WHERE id = $1', [userId]);
    const user = userRes.rows[0];

    const isMatch = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isMatch) return res.status(400).json({ error: 'Incorrect current password' });

    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(newPassword, salt);
    await query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, userId]);

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.put('/:id/fcm-token', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.params.id;
    if (req.auth?.id !== userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const { fcmToken } = req.body;
    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }

    await query('UPDATE users SET fcm_token = $1 WHERE id = $2', [fcmToken, userId]);
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/favorites', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.params.id;
    if (req.auth?.id !== userId) return res.status(403).json({ error: 'Forbidden' });

    const result = await query(
      `SELECT property_id FROM favorites WHERE user_id = $1`,
      [userId]
    );
    res.json({ data: result.rows });
  } catch (error) {
    next(error);
  }
});

router.post('/:id/favorites', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.params.id;
    if (req.auth?.id !== userId) return res.status(403).json({ error: 'Forbidden' });

    const { propertyId } = req.body;
    if (!propertyId) return res.status(400).json({ error: 'propertyId is required' });

    await query(
      `INSERT INTO favorites (user_id, property_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
      [userId, propertyId]
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

router.delete('/:id/favorites/:propertyId', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.params.id;
    const { propertyId } = req.params;
    if (req.auth?.id !== userId) return res.status(403).json({ error: 'Forbidden' });

    await query(
      `DELETE FROM favorites WHERE user_id = $1 AND property_id = $2`,
      [userId, propertyId]
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

export default router;