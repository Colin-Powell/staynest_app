import { Router } from 'express';
import { OAuth2Client } from 'google-auth-library';
import { env } from '../config.js';
import { query } from '../db.js';
import jwt from 'jsonwebtoken';

const router = Router();
const client = new OAuth2Client(env.googleClientId);

// Exchange Google ID token for server JWT and user record
router.post('/', async (req, res, next) => {
  try {
    const { idToken, role } = req.body as { idToken?: string; role?: string };
    if (!idToken) return res.status(400).json({ error: 'idToken is required.' });

    const allowedAudiences = [
      env.googleClientId,
      env.googleWebClientId,
      '193200636263-vsbg83ntukhk0vcj8fkgtvfll3b4chk6.apps.googleusercontent.com',
      '193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com',
      '193200636263-d0l88jln8tojkbli1f6utkod9r4gm6u8.apps.googleusercontent.com',
    ].filter((v): v is string => Boolean(v && typeof v === 'string'));

    const ticket = await client.verifyIdToken({
      idToken,
      audience: [...new Set(allowedAudiences)],
    });
    const payload = ticket.getPayload();
    if (!payload || !payload.email || payload.email_verified !== true) {
      return res.status(400).json({ error: 'Invalid or unverified Google token.' });
    }

    const email = payload.email.toLowerCase();
    const name = payload.name || '';
    const avatar = payload.picture || null;
    const requestedRole = role?.toLowerCase() === 'landlord' ? 'landlord' : 'tenant';

    // Upsert user
    const exists = await query(
      'SELECT id, name, email, phone, role, roles, landlord_verified, verified, avatar FROM users WHERE email = $1 LIMIT 1',
      [email]
    );
    let user = exists.rows[0];
    if (!user) {
      const result = await query(
        `INSERT INTO users (name, email, avatar, verified, password_hash, role)
         VALUES ($1, $2, $3, true, '*', $4)
         RETURNING id, name, email, phone, role, roles, landlord_verified, verified, avatar`,
        [name, email, avatar, requestedRole]
      );
      user = result.rows[0];
    } else {
      // update avatar/name if missing, and upgrade to landlord role if selected and user was tenant
      const newRole = (requestedRole === 'landlord' && user.role === 'tenant') ? 'landlord' : user.role;
      const updateRes = await query(
        `UPDATE users
         SET name = COALESCE(NULLIF($1, ''), name),
             avatar = COALESCE(avatar, $2),
             role = $4
         WHERE id = $3
         RETURNING id, name, email, phone, role, roles, landlord_verified, verified, avatar`,
        [name, avatar, user.id, newRole]
      );
      user = updateRes.rows[0];
    }

    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role,
        roles: user.roles,
        landlord_verified: user.landlord_verified,
        verified: user.verified,
      },
      env.jwtSecret,
      { expiresIn: '15m' }
    );
    const refreshToken = jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: '30d' });

    return res.json({ data: { token: accessToken, accessToken, refreshToken, user } });
  } catch (err) {
    next(err);
  }
});

export default router;
