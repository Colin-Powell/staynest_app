import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
const router = Router();
router.get('/relevant', requireAuth, async (_req, res) => {
    try {
        const result = await query('SELECT * FROM promotions WHERE active = true ORDER BY created_at DESC LIMIT 1');
        // If no promotions, just send a dummy one for testing the UI
        if (result.rows.length === 0) {
            return res.json({ data: [{
                        id: 'promo-1',
                        title: 'Discount on Beach Villas',
                        description: 'Get 20% off your first beach villa booking.',
                        image_url: 'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'
                    }] });
        }
        return res.json({ data: result.rows });
    }
    catch (err) {
        return res.status(500).json({ error: 'Failed' });
    }
});
export default router;
//# sourceMappingURL=promotions.js.map