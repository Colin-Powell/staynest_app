import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Save a message to database
router.post('/', requireAuth, async (req, res, next) => {
  try {
    const { to_user_id, text } = req.body as {
      to_user_id?: string;
      text?: string;
    };

    if (!to_user_id || !text) {
      return res.status(400).json({ error: 'to_user_id and text are required.' });
    }

    const from_user_id = req.auth!.id;

    // Verify both users exist
    const toUserResult = await query('SELECT id FROM users WHERE id = $1 LIMIT 1', [to_user_id]);
    if (toUserResult.rowCount === 0) {
      return res.status(404).json({ error: 'Recipient not found.' });
    }

    const result = await query(
      `INSERT INTO messages (from_user_id, to_user_id, text)
       VALUES ($1, $2, $3)
       RETURNING id, from_user_id, to_user_id, text, created_at`,
      [from_user_id, to_user_id, text.trim()],
    );

    return res.status(201).json({ data: result.rows[0] });
  } catch (error) {
    next(error);
  }
});

// Fetch conversation history between two users (paginated)
router.get('/conversation/:userId', requireAuth, async (req, res, next) => {
  try {
    const { userId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;

    const currentUserId = req.auth!.id;

    // Fetch messages in this conversation (both directions, ordered by time)
    const result = await query(
      `SELECT id, from_user_id, to_user_id, text, created_at
       FROM messages
       WHERE (from_user_id = $1 AND to_user_id = $2)
          OR (from_user_id = $2 AND to_user_id = $1)
       ORDER BY created_at DESC
       LIMIT $3 OFFSET $4`,
      [currentUserId, userId, limit, offset],
    );

    return res.json({
      data: {
        messages: result.rows.reverse(), // Reverse to show oldest first
        count: result.rowCount,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Fetch all conversations (unique users the current user has messaged)
router.get('/conversations', requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;

    const result = await query(
      `SELECT DISTINCT
         CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END as user_id,
         (SELECT name FROM users u WHERE u.id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END) as user_name,
         (SELECT avatar FROM users u WHERE u.id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END) as user_avatar,
         (SELECT text FROM messages m2 WHERE 
           (m2.from_user_id = $1 AND m2.to_user_id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END)
           OR (m2.from_user_id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END AND m2.to_user_id = $1)
           ORDER BY m2.created_at DESC LIMIT 1) as last_message,
         (SELECT created_at FROM messages m2 WHERE 
           (m2.from_user_id = $1 AND m2.to_user_id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END)
           OR (m2.from_user_id = CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END AND m2.to_user_id = $1)
           ORDER BY m2.created_at DESC LIMIT 1) as last_message_at
       FROM messages
       WHERE from_user_id = $1 OR to_user_id = $1
       ORDER BY last_message_at DESC`,
      [currentUserId],
    );

    return res.json({
      data: {
        conversations: result.rows,
      },
    });
  } catch (error) {
    next(error);
  }
});

export default router;
