import { Server as IOServer } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from './config.js';
import { query } from './db.js';
export function initSocket(server) {
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
                socket.handshake.headers?.authorization?.split(' ')[1];
            if (!token)
                return next();
            const payload = jwt.verify(token, env.jwtSecret);
            socket.data.userId = payload?.id?.toString();
            return next();
        }
        catch (err) {
            console.warn('Socket auth failed:', err);
            return next();
        }
    });
    io.on('connection', (socket) => {
        const uid = socket.data.userId;
        if (uid) {
            socket.join(`user:${uid}`);
            console.log(`Socket connected for user ${uid}`);
        }
        else {
            console.log('Socket connected (unauthenticated client)');
        }
        // Messaging: client emits { to: string (user UUID), text: string }
        socket.on('message', async (msg) => {
            const from = uid;
            if (!from) {
                socket.emit('error', { message: 'Not authenticated' });
                return;
            }
            const text = msg.text?.trim();
            if (!text)
                return;
            try {
                // Save message to database
                const result = await query(`INSERT INTO messages (from_user_id, to_user_id, text)
           VALUES ($1, $2, $3)
           RETURNING id, from_user_id, to_user_id, text, created_at`, [from, msg.to, text]);
                const payload = result.rows[0];
                // Emit to recipient room and back to sender for echo
                if (msg.to)
                    io.to(`user:${msg.to}`).emit('message', payload);
                socket.emit('message', payload);
            }
            catch (err) {
                console.error('Message save failed:', err);
                socket.emit('error', { message: 'Failed to save message' });
            }
        });
        // Signaling events for WebRTC: offer/answer/ice
        socket.on('offer', (data) => {
            const to = data.to;
            if (!to || !uid) {
                socket.emit('error', { message: 'Invalid offer' });
                return;
            }
            io.to(`user:${to}`).emit('offer', { from: uid, sdp: data.sdp });
        });
        socket.on('answer', (data) => {
            const to = data.to;
            if (!to || !uid) {
                socket.emit('error', { message: 'Invalid answer' });
                return;
            }
            io.to(`user:${to}`).emit('answer', { from: uid, sdp: data.sdp });
        });
        socket.on('ice-candidate', (data) => {
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
//# sourceMappingURL=socket.js.map