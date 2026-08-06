import { Router } from 'express';
import { OAuth2Client } from 'google-auth-library';
import { env } from '../config.js';
import { query } from '../db.js';
import jwt from 'jsonwebtoken';

const router = Router();
const client = new OAuth2Client(env.googleClientId);

// Exchange Google ID token for server JWT and user record
router.post('/google', async (req, res, next) => {
  try {
    const { idToken } = req.body as { idToken?: string };
    if (!idToken) return res.status(400).json({ error: 'idToken is required.' });

    const ticket = await client.verifyIdToken({ idToken, audience: env.googleClientId });
    const payload = ticket.getPayload();
    if (!payload || !payload.email) return res.status(400).json({ error: 'Invalid Google token.' });

    const email = payload.email.toLowerCase();
    const name = payload.name || '';
    const avatar = payload.picture || null;

    // Upsert user
    const exists = await query('SELECT id, name, email, phone, role, verified FROM users WHERE email = $1 LIMIT 1', [email]);
    let user = exists.rows[0];
    if (!user) {
      const result = await query(`INSERT INTO users (name, email, avatar, verified, password_hash) VALUES ($1, $2, $3, true, '*') RETURNING id, name, email, phone, role, verified`, [name, email, avatar]);
      user = result.rows[0];
    } else {
      // update avatar/name if missing
      await query(`UPDATE users SET name = COALESCE(NULLIF($1, ''), name), avatar = COALESCE($2, avatar) WHERE id = $3`, [name, avatar, user.id]);
    }

    const accessToken = jwt.sign({ id: user.id, email: user.email, role: user.role, verified: user.verified }, env.jwtSecret, { expiresIn: '15m' });
    const refreshToken = jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: '30d' });

    return res.json({ data: { token: accessToken, accessToken, refreshToken, user } });
  } catch (err) {
    next(err);
  }
});

export default router;
