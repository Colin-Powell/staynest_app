import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import bcrypt from 'bcrypt';

const router = Router();

router.patch('/profile', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth?.id;
    const {
      name, phone, avatar,
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


    await query(
      `UPDATE users
       SET name = COALESCE($1, name),
           phone = COALESCE($2, phone),
           avatar = COALESCE($3, avatar),
           business_name = COALESCE($4, business_name),
           business_type = COALESCE($5, business_type),
           business_description = COALESCE($6, business_description),
           tax_id = COALESCE($7, tax_id),
           years_in_business = COALESCE($8, years_in_business),
           settings = COALESCE($9, settings)
       WHERE id = $10`,
      [
        name, phone, avatar,
        businessName, businessType, businessDescription,
        taxId, yearsInBusiness,
        settings ? JSON.stringify(settings) : null,
        userId
      ]
    );

    res.json({ ok: true });
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

export default router;