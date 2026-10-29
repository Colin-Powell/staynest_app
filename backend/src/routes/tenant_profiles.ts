import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import {
  getPreferenceCompletion,
  getProfileCompletion,
  isPreferenceField,
  reminderState,
  SUPPORTED_PROPERTY_TYPES,
} from '../services/profile_completion.js';

const router = Router();

router.get('/completion', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const result = await query(
      `SELECT u.name, u.settings, tp.preferred_cities, tp.budget_min, tp.budget_max,
              tp.preferred_categories
         FROM users u
         LEFT JOIN tenant_profiles tp ON tp.user_id = u.id
        WHERE u.id = $1`,
      [req.auth!.id],
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found.' });

    const user = result.rows[0];
    const savedLocations: unknown[] = Array.isArray(user.preferred_cities)
      ? user.preferred_cities
      : [];
    const locationValues = savedLocations.filter(
      (location: unknown): location is string =>
        typeof location === 'string' && !!location.trim(),
    );
    const supportedLocations = await query(
      `SELECT requested.location
         FROM unnest($1::text[]) WITH ORDINALITY AS requested(location, position)
        WHERE EXISTS (
                SELECT 1 FROM locations
                 WHERE lower(name) = lower(requested.location)
                    OR lower(normalized_name) = lower(requested.location)
                    OR lower(town) = lower(requested.location)
                    OR lower(county) = lower(requested.location)
              )
           OR EXISTS (
                SELECT 1 FROM properties
                 WHERE lower(city) = lower(requested.location)
                    OR lower(county) = lower(requested.location)
              )
        ORDER BY requested.position`,
      [locationValues.map((location) => location.trim())],
    );
    user.preferred_cities = supportedLocations.rows.map((row) => row.location);
    const preferences = getPreferenceCompletion(user);
    res.json({
      data: {
        profile: getProfileCompletion(user.name),
        preferences,
        reminder: reminderState(user.settings, preferences),
      },
    });
  } catch (error) {
    next(error);
  }
});

router.post('/reminder', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { action, field } = req.body ?? {};
    if (!isPreferenceField(field) || !['shown', 'snooze'].includes(action)) {
      return res.status(400).json({ error: 'A valid reminder action and field are required.' });
    }

    const reminderUpdate = action === 'snooze'
      ? { field, snoozedUntil: new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString() }
      : { field, lastShownAt: new Date().toISOString() };
    await query(
      `UPDATE users
          SET settings = COALESCE(settings, '{}'::jsonb) ||
            jsonb_build_object(
              'onboardingReminder',
              COALESCE(settings->'onboardingReminder', '{}'::jsonb) || $1::jsonb
            )
        WHERE id = $2`,
      [JSON.stringify(reminderUpdate), req.auth!.id],
    );
    res.json({ ok: true, data: reminderUpdate });
  } catch (error) {
    next(error);
  }
});

const profileFields = [
  'monthly_income', 'budget_min', 'budget_max', 'status', 'household_size', 'pets',
  'preferred_categories', 'preferred_cities', 'move_in_date', 'opt_in_personalized',
  'consent_given', 'consent_at', 'data_retention_days', 'preferred_name', 'bio',
  'languages', 'interests', 'institution', 'campus', 'course', 'year_of_study',
  'expected_graduation', 'preferred_amenities', 'distance_preference',
  'move_in_preference', 'room_preference', 'gender_preference',
] as const;
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
    if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
      return res.status(400).json({ error: 'Profile updates must be an object.' });
    }
    if ('budget_min' in req.body || 'budget_max' in req.body) {
      const minimum = req.body.budget_min == null ? null : Number(req.body.budget_min);
      const maximum = req.body.budget_max == null ? null : Number(req.body.budget_max);
      if ((minimum !== null && (!Number.isFinite(minimum) || minimum < 0)) ||
          (maximum !== null && (!Number.isFinite(maximum) || maximum <= 0)) ||
          (minimum !== null && maximum !== null && maximum < minimum)) {
        return res.status(400).json({ error: 'Enter a valid monthly budget range.' });
      }
    }
    for (const field of ['preferred_cities', 'preferred_categories'] as const) {
      if (!(field in req.body)) continue;
      const values = req.body[field];
      if (!Array.isArray(values) || values.length > 20 || values.some(
        (value) => typeof value !== 'string' || value.trim().length === 0 || value.trim().length > 100,
      )) {
        return res.status(400).json({ error: `Enter valid ${field === 'preferred_cities' ? 'locations' : 'property types'}.` });
      }
      if (field === 'preferred_categories' && values.some(
        (value: string) => !SUPPORTED_PROPERTY_TYPES.has(value.trim().toLowerCase()),
      )) {
        return res.status(400).json({ error: 'Choose a supported property type.' });
      }
    }
    if ('preferred_cities' in req.body && req.body.preferred_cities.length > 0) {
      const locations = (req.body.preferred_cities as string[])
        .map((location) => location.trim());
      const supported = await query(
        `SELECT requested.location
           FROM unnest($1::text[]) WITH ORDINALITY AS requested(location, position)
          WHERE EXISTS (
                  SELECT 1 FROM locations
                   WHERE lower(name) = lower(requested.location)
                      OR lower(normalized_name) = lower(requested.location)
                      OR lower(town) = lower(requested.location)
                      OR lower(county) = lower(requested.location)
                )
             OR EXISTS (
                  SELECT 1 FROM properties
                   WHERE lower(city) = lower(requested.location)
                      OR lower(county) = lower(requested.location)
                )`,
        [locations],
      );
      if (supported.rows.length !== locations.length) {
        const valid = new Set(supported.rows.map((row) => String(row.location).toLowerCase()));
        const invalid = locations.find((location) => !valid.has(location.toLowerCase()));
        return res.status(400).json({
          error: `Choose a listed location for "${invalid ?? ''}".`,
        });
      }
    }
    const body = req.body as Record<string, any>;
    const fields = profileFields.filter((field) => field in body);
    if (fields.length === 0) {
      return res.status(400).json({ error: 'No profile fields were provided.' });
    }
    const columns = [...fields, 'user_id'];
    const values = [...fields.map((field) => body[field]), userId];
    const placeholders = fields.map((_, index) => `$${index + 1}`);

    const result = await query(
      `INSERT INTO tenant_profiles (${columns.join(', ')})
       VALUES (${[...placeholders, `$${values.length}`].join(', ')})
       ON CONFLICT (user_id) DO UPDATE SET
         ${fields.map((field) => `${field} = EXCLUDED.${field}`).join(',\n         ')},
         updated_at = now()
       RETURNING *`,
      values,
    );

    res.status(200).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

export default router;
