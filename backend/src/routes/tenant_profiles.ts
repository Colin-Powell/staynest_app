import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

const profileFields = [
  'monthly_income', 'budget_min', 'budget_max', 'status', 'household_size', 'pets',
  'preferred_categories', 'preferred_cities', 'move_in_date', 'opt_in_personalized',
  'consent_given', 'consent_at', 'data_retention_days', 'preferred_name', 'bio',
  'languages', 'interests', 'institution', 'campus', 'course', 'year_of_study',
  'expected_graduation', 'preferred_amenities', 'distance_preference',
  'move_in_preference', 'room_preference', 'gender_preference',
] as const;

function profilePayload(body: Record<string, any>): Record<string, any> {
  return Object.fromEntries(profileFields.map((field) => [field, body[field] ?? null]));
}


// Get current user's profile
router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth!.id;
    const result = await query('SELECT * FROM tenant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
    if (result.rowCount === 0) {
      return res.json({ data: null });
    }
    res.json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Create or update profile for current user
router.post('/', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth!.id;
    const body = profilePayload(req.body as Record<string, any>);

    // Upsert
    const result = await query(
      `INSERT INTO tenant_profiles (${profileFields.join(', ')}, user_id)
       VALUES (${profileFields.map((_, index) => `$${index + 2}`).join(', ')}, $1)
       ON CONFLICT (user_id) DO UPDATE SET
         ${profileFields.map((field) => `${field} = COALESCE(EXCLUDED.${field}, tenant_profiles.${field})`).join(',\n         ')},
         updated_at = now()
       RETURNING *`,
      [
        userId,
        ...profileFields.map((field) => body[field]),
      ],
    );

    res.status(200).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

export default router;
