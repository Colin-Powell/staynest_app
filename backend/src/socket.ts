import { Server as IOServer } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from './config.js';
import { pool, query } from './db.js';

import type { Socket } from 'socket.io';
import type { PoolClient } from 'pg';

const PRESENCE_LEASE_SECONDS = 45;
const PRESENCE_SWEEP_MS = 15_000;

interface ExtendedSocket extends Socket {
  data: {
    userId?: string;
  };
}

export let ioInstance: IOServer;

async function withUserPresenceLock<T>(
  userId: string,
  callback: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const user = await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
    if (user.rows.length === 0) throw new Error('Presence user no longer exists');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function conversationPartners(userId: string): Promise<string[]> {
  const result = await query<{ user_id: string }>(
    `SELECT DISTINCT CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END AS user_id
       FROM messages
      WHERE from_user_id = $1 OR to_user_id = $1`,
    [userId],
  );
  return result.rows.map((row) => row.user_id);
}

async function emitPresenceToConversationPartners(
  io: IOServer,
  userId: string,
  online: boolean,
  revision: number,
  lastSeenAt: string | null = null,
): Promise<void> {
  const partners = await conversationPartners(userId);
  for (const partnerId of partners) {
    io.to(`user:${partnerId}`).emit('presence', {
      userId,
      online,
      lastSeenAt,
      revision,
    });
  }
}

async function refreshPresenceLease(
  io: IOServer,
  connectionId: string,
  userId: string,
): Promise<void> {
  const revision = await withUserPresenceLock(userId, async (client) => {
    await client.query(
      'DELETE FROM presence_connections WHERE user_id = $1 AND expires_at <= now()',
      [userId],
    );
    const active = await client.query(
      'SELECT 1 FROM presence_connections WHERE user_id = $1 AND expires_at > now() LIMIT 1',
      [userId],
    );
    await client.query(
      `INSERT INTO presence_connections (connection_id, user_id, expires_at)
       VALUES ($1, $2, now() + ($3 * interval '1 second'))
       ON CONFLICT (connection_id) DO UPDATE SET expires_at = EXCLUDED.expires_at`,
      [connectionId, userId, PRESENCE_LEASE_SECONDS],
    );
    if (active.rows.length !== 0) return null;
    const updated = await client.query<{ presence_revision: string | number }>(
      `UPDATE users
          SET presence_revision = presence_revision + 1
        WHERE id = $1
        RETURNING presence_revision`,
      [userId],
    );
    return Number(updated.rows[0]?.presence_revision ?? 0);
  });
  if (revision !== null) {
    await emitPresenceToConversationPartners(io, userId, true, revision);
  }
}

async function sendConversationPresence(socket: ExtendedSocket, userId: string): Promise<void> {
  const result = await query<{
    user_id: string;
    online: boolean;
    last_seen_at: Date | null;
    presence_revision: string | number;
  }>(
    `SELECT partners.user_id,
            EXISTS (
              SELECT 1 FROM presence_connections pc
               WHERE pc.user_id = partners.user_id AND pc.expires_at > now()
            ) AS online,
            u.last_seen_at,
            u.presence_revision
       FROM (
         SELECT DISTINCT CASE WHEN from_user_id = $1 THEN to_user_id ELSE from_user_id END AS user_id
           FROM messages
          WHERE from_user_id = $1 OR to_user_id = $1
       ) partners
       JOIN users u ON u.id = partners.user_id`,
    [userId],
  );
  for (const presence of result.rows) {
    socket.emit('presence', {
      userId: presence.user_id,
      online: presence.online,
      lastSeenAt: presence.last_seen_at?.toISOString() ?? null,
      revision: Number(presence.presence_revision),
    });
  }
}

export async function emitDirectConversationPresence(
  userId: string,
  recipientId: string,
): Promise<void> {
  const conversation = await query<{
    last_seen_at: Date | null;
    online: boolean;
    presence_revision: string | number;
  }>(
    `SELECT u.last_seen_at,
            EXISTS (
              SELECT 1 FROM presence_connections pc
               WHERE pc.user_id = u.id AND pc.expires_at > now()
            ) AS online,
            u.presence_revision
       FROM users u
      WHERE u.id = $1
        AND EXISTS (
          SELECT 1 FROM messages m
           WHERE (m.from_user_id = $1 AND m.to_user_id = $2)
              OR (m.from_user_id = $2 AND m.to_user_id = $1)
        )`,
    [userId, recipientId],
  );
  const presence = conversation.rows[0];
  if (!presence || !ioInstance) return;
  ioInstance.to(`user:${recipientId}`).emit('presence', {
    userId,
    online: presence.online,
    lastSeenAt: presence.last_seen_at?.toISOString() ?? null,
    revision: Number(presence.presence_revision),
  });
}

async function expirePresenceLeases(io: IOServer): Promise<void> {
  const result = await query<{ user_id: string }>(
    `SELECT DISTINCT user_id FROM presence_connections WHERE expires_at <= now()`,
  );
  for (const { user_id: userId } of result.rows) {
    const presence = await withUserPresenceLock(userId, async (client) => {
      const expired = await client.query(
        'DELETE FROM presence_connections WHERE user_id = $1 AND expires_at <= now() RETURNING connection_id',
        [userId],
      );
      if (expired.rows.length === 0) return null;
      const active = await client.query(
        'SELECT 1 FROM presence_connections WHERE user_id = $1 AND expires_at > now() LIMIT 1',
        [userId],
      );
      if (active.rows.length !== 0) return null;
      const updated = await client.query<{
        last_seen_at: Date;
        presence_revision: string | number;
      }>(
        `UPDATE users
            SET last_seen_at = now(), presence_revision = presence_revision + 1
          WHERE id = $1
          RETURNING last_seen_at, presence_revision`,
        [userId],
      );
      if (!updated.rows[0]) return null;
      return {
        lastSeenAt: updated.rows[0].last_seen_at.toISOString(),
        revision: Number(updated.rows[0].presence_revision),
      };
    });
    if (presence) {
      await emitPresenceToConversationPartners(
        io,
        userId,
        false,
        presence.revision,
        presence.lastSeenAt,
      );
    }
  }
}

export function initSocket(server: import('http').Server) {
  const io = new IOServer(server, {
    cors: {
      origin: env.corsOrigin,
      methods: ['GET', 'POST'],
      allowedHeaders: ['Authorization'],
    },
  });
  
  ioInstance = io;

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token ||
        (socket.handshake.headers?.authorization as string | undefined)?.split(' ')[1];
      if (typeof token !== 'string' || !token) {
        return next(new Error('Authentication required'));
      }
      const payload = jwt.verify(token, env.jwtSecret) as any;
      if (!payload?.id) return next(new Error('Invalid authentication token'));
      (socket as ExtendedSocket).data.userId = payload.id.toString();
      return next();
    } catch (err) {
      console.warn('Socket auth failed:', err);
      return next(new Error('Invalid or expired authentication token'));
    }
  });

  const presenceSweep = setInterval(() => {
    void expirePresenceLeases(io).catch((error) => {
      console.error('[Presence] lease expiry failed:', error);
    });
  }, PRESENCE_SWEEP_MS);
  presenceSweep.unref();

  io.on('connection', (socket: ExtendedSocket) => {
    const uid = socket.data.userId;
    if (!uid) return socket.disconnect(true);

    socket.join(`user:${uid}`);
    console.log(`Socket connected for user ${uid}`);

    void refreshPresenceLease(io, socket.id, uid).then(async () => {
      await sendConversationPresence(socket, uid);
    }).catch((error) => {
      console.error('[Presence] connection registration failed:', error);
      socket.disconnect(true);
    });

    socket.on('presence:heartbeat', () => {
      void refreshPresenceLease(io, socket.id, uid).catch((error) => {
        console.error('[Presence] heartbeat refresh failed:', error);
      });
    });

    // Messaging: client emits { to: string (user UUID), text: string }
    socket.on('message', async (_msg: { to: string; text: string }) => {
      // We no longer insert into DB here to avoid duplicates!
      // The frontend calls REST /messages which inserts and emits.
      // This listener can be kept as a no-op or fallback relay, but 
      // it's safer to just ignore to prevent duplicates if REST is used.
    });

    // Typing indicator: client emits { to, isTyping }
    // Forward to recipient room so UI can show typing status.
    socket.on('typing', (data: { to?: string; isTyping?: boolean }) => {
      if (!uid) return;
      const to = data?.to;
      if (!to) return;
      const isTyping = data?.isTyping === true;
      io.to(`user:${to}`).emit('typing', { userId: uid, isTyping });
    });

    // Seen receipts: REST persists the receipt; Socket.IO only notifies its sender.
    socket.on('mark_seen', async (data: { to?: string; messageIds?: string[] }) => {
      if (!uid) return;
      const to = data?.to;
      const uuidPattern =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      if (!to || !uuidPattern.test(to)) return;
      const requestedIds = (data?.messageIds ?? [])
        .map((value) => value?.toString())
        .filter((value) => uuidPattern.test(value))
        .slice(0, 100);
      if (requestedIds.length === 0) return;

      try {
        const readMessages = await query<{ id: string }>(
          `SELECT m.id
             FROM messages m
            WHERE m.id = ANY($1::uuid[])
              AND m.from_user_id = $2
              AND m.to_user_id = $3
              AND m.deleted_for_everyone_at IS NULL
              AND EXISTS (
                SELECT 1 FROM message_reads mr
                 WHERE mr.message_id = m.id AND mr.user_id = $3
              )`,
          [requestedIds, to, uid],
        );
        if (readMessages.rows.length > 0) {
          io.to(`user:${to}`).emit('mark_seen', {
            userId: uid,
            messageIds: readMessages.rows.map((message) => message.id),
          });
        }
      } catch (error) {
        console.error('[Messages] seen receipt failed:', error);
      }
    });

    socket.on('message_delivered', async (data: { messageIds?: string[] }) => {
      const messageIds = (data?.messageIds ?? [])
        .map((value) => value?.toString())
        .filter((value) =>
          /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value),
        )
        .slice(0, 100);
      if (messageIds.length === 0) return;

      try {
        const delivered = await query<{
          id: string;
          from_user_id: string;
          conversation_id: string;
        }>(
          `UPDATE messages
              SET delivered_at = COALESCE(delivered_at, now())
            WHERE id = ANY($1::uuid[])
              AND to_user_id = $2
              AND deleted_for_everyone_at IS NULL
            RETURNING id, from_user_id, conversation_id`,
          [messageIds, uid],
        );
        for (const message of delivered.rows) {
          io.to(`user:${message.from_user_id}`).emit('message_delivered', {
            userId: uid,
            conversationId: message.conversation_id,
            messageIds: [message.id],
          });
        }
      } catch (error) {
        console.error('[Messages] delivery receipt failed:', error);
      }
    });

    // Signaling events for WebRTC: offer/answer/ice

    socket.on('offer', (data: any) => {
      const to = data.to;
      if (!to || !uid) {
        socket.emit('error', { message: 'Invalid offer' });
        return;
      }
      io.to(`user:${to}`).emit('offer', { from: uid, sdp: data.sdp });
    });

    socket.on('answer', (data: any) => {
      const to = data.to;
      if (!to || !uid) {
        socket.emit('error', { message: 'Invalid answer' });
        return;
      }
      io.to(`user:${to}`).emit('answer', { from: uid, sdp: data.sdp });
    });

    socket.on('ice-candidate', (data: any) => {
      const to = data.to;
      if (!to || !uid) {
        socket.emit('error', { message: 'Invalid ICE candidate' });
        return;
      }
      io.to(`user:${to}`).emit('ice-candidate', { from: uid, candidate: data.candidate });
    });

    socket.on('disconnect', (reason) => {
      void withUserPresenceLock(uid, async (client) => {
        const removed = await client.query(
          'DELETE FROM presence_connections WHERE connection_id = $1 AND user_id = $2 RETURNING connection_id',
          [socket.id, uid],
        );
        if (removed.rows.length === 0) return null;
        const active = await client.query(
          'SELECT 1 FROM presence_connections WHERE user_id = $1 AND expires_at > now() LIMIT 1',
          [uid],
        );
        if (active.rows.length !== 0) return null;
        const updated = await client.query<{
          last_seen_at: Date;
          presence_revision: string | number;
        }>(
          `UPDATE users
              SET last_seen_at = now(), presence_revision = presence_revision + 1
            WHERE id = $1
            RETURNING last_seen_at, presence_revision`,
          [uid],
        );
        if (!updated.rows[0]) return null;
        return {
          lastSeenAt: updated.rows[0].last_seen_at.toISOString(),
          revision: Number(updated.rows[0].presence_revision),
        };
      }).then(async (presence) => {
        if (presence) {
          await emitPresenceToConversationPartners(
            io,
            uid,
            false,
            presence.revision,
            presence.lastSeenAt,
          );
        }
      }).catch((error) => {
        console.error('[Presence] disconnect cleanup failed:', error);
      });
      console.log('Socket disconnected', reason);
    });
  });

  return io;
}