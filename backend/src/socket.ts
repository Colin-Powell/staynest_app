import { Server as IOServer } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from './config.js';
import { query } from './db.js';

import type { Socket } from 'socket.io';

interface ExtendedSocket extends Socket {
  data: {
    userId?: string;
  };
}

export function initSocket(server: import('http').Server) {
  const io = new IOServer(server, {
    cors: {
      origin: env.corsOrigin,
      methods: ['GET', 'POST'],
      allowedHeaders: ['Authorization'],
    },
  });

  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token ||
        (socket.handshake.headers?.authorization as string | undefined)?.split(' ')[1];
      if (!token) return next();
      const payload = jwt.verify(token, env.jwtSecret) as any;
      (socket as ExtendedSocket).data.userId = payload?.id?.toString();
      return next();
    } catch (err) {
      console.warn('Socket auth failed:', err);
      return next();
    }
  });

  io.on('connection', (socket: ExtendedSocket) => {
    const uid = socket.data.userId;
    if (uid) {
      socket.join(`user:${uid}`);
      console.log(`Socket connected for user ${uid}`);
    } else {
      console.log('Socket connected (unauthenticated client)');
    }

    // Messaging: client emits { to: string (user UUID), text: string }
    socket.on('message', async (msg: { to: string; text: string }) => {
      const from = uid;
      if (!from) {
        socket.emit('error', { message: 'Not authenticated' });
        return;
      }

      const text = msg.text?.trim();
      if (!text) return;

      try {
        // Save message to database
        const result = await query(
          `INSERT INTO messages (from_user_id, to_user_id, text)
           VALUES ($1, $2, $3)
           RETURNING id, from_user_id, to_user_id, text, created_at`,
          [from, msg.to, text],
        );

        const payload = result.rows[0];

        // FIX: only emit to the RECIPIENT — never echo back to sender.
        // The sender already appended the message optimistically in the UI.
        // Ensure we don't emit if the recipient is the sender
        if (msg.to && msg.to !== from) {
          io.to(`user:${msg.to}`).emit('message', payload);
        }

        // Emit a delivery confirmation to sender (no message content echo)
        // so the client can update message status if needed.
        socket.emit('message:sent', { id: payload.id });

      } catch (err) {
        console.error('Message save failed:', err);
        socket.emit('error', { message: 'Failed to save message' });
      }
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

    // Seen receipts: client emits { to, messageIds }
    // For now we forward receipt event to the recipient; DB persistence is handled by REST `mark-read`.
    socket.on('mark_seen', (data: { to?: string; messageIds?: string[] }) => {
      if (!uid) return;
      const to = data?.to;
      if (!to) return;
      const messageIds = (data?.messageIds ?? []).map((x) => x?.toString()).filter(Boolean);
      io.to(`user:${to}`).emit('mark_seen', { userId: uid, messageIds });
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
      console.log('Socket disconnected', reason);
    });
  });

  return io;
}