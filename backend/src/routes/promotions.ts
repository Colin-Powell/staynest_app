import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';
import { Request, Response } from 'express';

const router = Router();

router.get('/relevant', requireAuth, async (_req: Request, res: Response) => {
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
  } catch (err) {
    return res.status(500).json({ error: 'Failed' });
  }
});

router.get('/me', requireAuth, async (req: Request, res: Response) => {
  try {
    const result = await query(
      `SELECT pc.*, p.title, p.image_url
       FROM promotion_campaigns pc
       JOIN properties p ON p.id = pc.property_id
       WHERE pc.landlord_id = $1
         AND pc.active = true
         AND pc.end_date > NOW()
       ORDER BY pc.end_date ASC`,
      [req.auth?.id],
    );
    return res.json({ data: result.rows });
  } catch (err) {
    console.error('[Promotions] Failed to fetch landlord promotions:', err);
    return res.status(500).json({ error: 'Failed to fetch promotions.' });
  }
});

export default router;
