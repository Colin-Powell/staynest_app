import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
// Get current user's profile
router.get('/me', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        const result = await query('SELECT * FROM tenant_profiles WHERE user_id = $1 LIMIT 1', [userId]);
        if (result.rowCount === 0) {
            return res.json({ data: null });
        }
        res.json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
// Create or update profile for current user
router.post('/', requireAuth, async (req, res, next) => {
    try {
        const userId = req.auth.id;
        const body = req.body;
        // Upsert
        const result = await query(`INSERT INTO tenant_profiles (user_id, monthly_income, budget_min, budget_max, status, household_size, pets, preferred_categories, preferred_cities, move_in_date, opt_in_personalized, consent_given, consent_at, data_retention_days)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12, $13, $14)
       ON CONFLICT (user_id) DO UPDATE SET
         monthly_income = EXCLUDED.monthly_income,
         budget_min = EXCLUDED.budget_min,
         budget_max = EXCLUDED.budget_max,
         status = EXCLUDED.status,
         household_size = EXCLUDED.household_size,
         pets = EXCLUDED.pets,
         preferred_categories = EXCLUDED.preferred_categories,
         preferred_cities = EXCLUDED.preferred_cities,
         move_in_date = EXCLUDED.move_in_date,
         opt_in_personalized = EXCLUDED.opt_in_personalized,
         consent_given = EXCLUDED.consent_given,
         consent_at = COALESCE(EXCLUDED.consent_at, tenant_profiles.consent_at),
         data_retention_days = EXCLUDED.data_retention_days,
         updated_at = now()
       RETURNING *`, [
            userId,
            body['monthly_income'] ?? null,
            body['budget_min'] ?? null,
            body['budget_max'] ?? null,
            body['status'] ?? null,
            body['household_size'] ?? null,
            body['pets'] ?? false,
            body['preferred_categories'] ?? null,
            body['preferred_cities'] ?? null,
            body['move_in_date'] ?? null,
            body['opt_in_personalized'] ?? true,
            body['consent_given'] ?? false,
            body['consent_at'] ?? null,
            body['data_retention_days'] ?? 365,
        ]);
        res.status(200).json({ data: result.rows[0] });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=tenant_profiles.js.map