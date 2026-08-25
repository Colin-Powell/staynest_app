import { Router, Request, Response, NextFunction } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// GET /api/notifications
router.get('/', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth!.id;
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;

    const result = await query(
      `SELECT id, title, body, data, is_read, created_at 
       FROM notifications 
       WHERE user_id = $1 
       ORDER BY created_at DESC 
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset]
    );

    const unreadCountRes = await query(
      `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`,
      [userId]
    );
    const unreadCount = parseInt(unreadCountRes.rows[0].count);

    res.json({
      data: result.rows,
      meta: { unreadCount }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /api/notifications/:id/read
router.put('/:id/read', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth!.id;
    const notifId = req.params.id;

    const result = await query(
      `UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING id`,
      [notifId, userId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

// PUT /api/notifications/read-all
router.put('/read-all', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.auth!.id;
    await query(
      `UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
      [userId]
    );
    res.json({ ok: true });
  } catch (error) {
    next(error);
  }
});

export default router;
