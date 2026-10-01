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
        const { idToken, role: requestedRole } = req.body;
        if (!idToken)
            return res.status(400).json({ error: 'idToken is required.' });
        const ticket = await client.verifyIdToken({
            idToken,
            audience: [...new Set([env.googleClientId, env.googleWebClientId])],
        });
        const payload = ticket.getPayload();
        if (!payload || !payload.email || payload.email_verified !== true)
            return res.status(400).json({ error: 'Invalid or unverified Google token.' });
        const email = payload.email.toLowerCase();
        const name = payload.name || '';
        const avatar = payload.picture || null;
        // Upsert user
        const exists = await query('SELECT id, name, email, phone, role, verified, avatar FROM users WHERE email = $1 LIMIT 1', [email]);
        let user = exists.rows[0];
        if (!user) {
            const newRole = (requestedRole === 'landlord' || requestedRole === 'tenant') ? requestedRole : 'tenant';
            const result = await query(`INSERT INTO users (name, email, avatar, verified, password_hash, role) VALUES ($1, $2, $3, true, '*', $4) RETURNING id, name, email, phone, role, verified, avatar`, [name, email, avatar, newRole]);
            user = result.rows[0];
        }
        else {
            // update avatar/name if missing
            const updateRes = await query(`UPDATE users SET name = COALESCE(NULLIF($1, ''), name), avatar = COALESCE(avatar, $2) WHERE id = $3 RETURNING id, name, email, phone, role, verified, avatar`, [name, avatar, user.id]);
            user = updateRes.rows[0];
        }
        const accessToken = jwt.sign({ id: user.id, email: user.email, role: user.role, verified: user.verified }, env.jwtSecret, { expiresIn: '15m' });
        const refreshToken = jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: '30d' });
        return res.json({ data: { token: accessToken, accessToken, refreshToken, user } });
    }
    catch (err) {
        next(err);
    }
});
export default router;
//# sourceMappingURL=google_auth.js.map