import { Router } from 'express';
import { query } from '../db.js';
import { requireAuth } from '../middleware/auth.js';

import { ioInstance } from '../socket.js';

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

    const payload = result.rows[0];

    // Emit to recipient over socket
    if (ioInstance && to_user_id !== from_user_id) {
      ioInstance.to(`user:${to_user_id}`).emit('message', payload);
    }

    return res.status(201).json({ data: payload });
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

router.post('/mark-read', requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;

    // Interpret payload as "mark all messages from these users as read for me".
    // Frontend currently sends: { user_ids: [...] }
    const { user_ids } = req.body as { user_ids?: string[] };

    const partnerIds = (user_ids ?? [])
      .map((v) => v?.toString())
      .filter(Boolean);

    // If no users provided, mark all incoming messages as read.
    if (partnerIds.length === 0) {
      const unreadFromResult = await query(
        `SELECT DISTINCT from_user_id
         FROM messages
         WHERE to_user_id = $1
           AND NOT EXISTS (
             SELECT 1
             FROM message_reads mr
             WHERE mr.user_id = $1
               AND mr.message_id = messages.id
           )`,
        [currentUserId],
      );

      const allPartnerIds = unreadFromResult.rows.map((r) => r.from_user_id);
      if (allPartnerIds.length === 0) {
        return res.status(200).json({ data: { updated: 0 } });
      }

      const now = new Date();

      // Insert read receipts for all unread messages
      const result = await query(
        `INSERT INTO message_reads (user_id, message_id, read_at)
         SELECT $1 as user_id, m.id as message_id, $2 as read_at
         FROM messages m
         WHERE m.to_user_id = $1
           AND m.from_user_id = ANY($3)
           AND NOT EXISTS (
             SELECT 1 FROM message_reads mr
             WHERE mr.user_id = $1 AND mr.message_id = m.id
           )`,
        [currentUserId, now, allPartnerIds],
      );

      return res.status(200).json({ data: { updated: result.rowCount } });
    }

    const now = new Date();

    // Upsert-ish behavior via INSERT ... SELECT + NOT EXISTS
    const result = await query(
      `INSERT INTO message_reads (user_id, message_id, read_at)
       SELECT $1 as user_id, m.id as message_id, $2 as read_at
       FROM messages m
       WHERE m.to_user_id = $1
         AND m.from_user_id = ANY($3)
         AND NOT EXISTS (
           SELECT 1 FROM message_reads mr
           WHERE mr.user_id = $1 AND mr.message_id = m.id
         )`,
      [currentUserId, now, partnerIds],
    );

    return res.status(200).json({ data: { updated: result.rowCount } });
  } catch (error) {
    next(error);
  }
});

// Fetch all conversations (unique users the current user has messaged)
router.get('/conversations', requireAuth, async (req, res, next) => {
  try {
    const currentUserId = req.auth!.id;

    const result = await query(
      `WITH partners AS (
         SELECT DISTINCT
           CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END as partner_id
         FROM messages
         WHERE from_user_id = $1 OR to_user_id = $1
       )
       SELECT
         p.partner_id as user_id,
         u.name as user_name,
         u.avatar as user_avatar,
         (SELECT m2.text
            FROM messages m2
           WHERE (m2.from_user_id = $1 AND m2.to_user_id = p.partner_id)
              OR (m2.from_user_id = p.partner_id AND m2.to_user_id = $1)
           ORDER BY m2.created_at DESC
           LIMIT 1) as last_message,
         (SELECT m2.created_at
            FROM messages m2
           WHERE (m2.from_user_id = $1 AND m2.to_user_id = p.partner_id)
              OR (m2.from_user_id = p.partner_id AND m2.to_user_id = $1)
           ORDER BY m2.created_at DESC
           LIMIT 1) as last_message_at,
         (
           SELECT COUNT(*)
           FROM messages m3
           WHERE m3.to_user_id = $1
             AND m3.from_user_id = p.partner_id
             AND NOT EXISTS (
               SELECT 1
               FROM message_reads mr
               WHERE mr.user_id = $1
                 AND mr.message_id = m3.id
             )
         ) as unread_count
       FROM partners p
       JOIN users u ON u.id = p.partner_id
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
