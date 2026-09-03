import { Router } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { query } from '../db.js';
import { env } from '../config.js';
import { requireAuth } from '../middleware/auth.js';
import { verifyOtp, createOtp, queueOtpEmail, revokeOtp } from '../services/email.js';
const router = Router();
const ADMIN_ACCESS_TOKEN_TTL = '24h';
const DEFAULT_ACCESS_TOKEN_TTL = '15m';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const NAME_PATTERN = /^[\p{L}][\p{L} .'-]{1,79}$/u;
const PHONE_PATTERN = /^(?:\+254|0)(?:7|1)\d{8}$/;
const PASSWORD_PATTERN = /^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,128}$/;
const accessTokenTtlForRole = (role) => {
    const normalizedRole = role?.toLowerCase();
    return normalizedRole === 'admin' ||
        normalizedRole === 'super_admin' ||
        normalizedRole === 'administrator'
        ? ADMIN_ACCESS_TOKEN_TTL
        : DEFAULT_ACCESS_TOKEN_TTL;
};
// Register new user
router.post('/register', async (req, res, next) => {
    try {
        const { name, email, password, phone, role } = req.body;
        if (!name || !email || !password || !phone) {
            return res.status(400).json({ error: 'Name, email, phone and password are required.' });
        }
        const normalizedEmail = email.trim().toLowerCase();
        const normalizedPhone = phone.trim();
        if (!NAME_PATTERN.test(name.trim())) {
            return res.status(400).json({ error: 'Enter a valid full name.' });
        }
        if (normalizedEmail.length > 254 || !EMAIL_PATTERN.test(normalizedEmail)) {
            return res.status(400).json({ error: 'Enter a valid email address.' });
        }
        if (!PHONE_PATTERN.test(normalizedPhone.replace(/[\s()-]/g, ''))) {
            return res.status(400).json({ error: 'Enter a valid Kenyan phone number.' });
        }
        if (!PASSWORD_PATTERN.test(password)) {
            return res.status(400).json({ error: 'Password must be 8-128 characters and include upper, lower, number and special character.' });
        }
        const exists = await query('SELECT id FROM users WHERE email = $1 LIMIT 1', [normalizedEmail]);
        if ((exists.rowCount ?? 0) > 0) {
            return res.status(409).json({ error: 'Email already registered.' });
        }
        const hash = await bcrypt.hash(password, 10);
        const allowedRoles = ['tenant', 'landlord', 'host'];
        const userRole = (role && allowedRoles.includes(role.toLowerCase())) ? role.toLowerCase() : 'tenant';
        const result = await query(`INSERT INTO users (name, email, phone, password_hash, role, verified)
       VALUES ($1, $2, $3, $4, $5, false)
       RETURNING id, name, email, phone, role, verified`, [name.trim(), normalizedEmail, normalizedPhone, hash, userRole]);
        const created = result.rows[0];
        const accessToken = jwt.sign({
            id: created.id,
            email: created.email,
            role: created.role,
            verified: created.verified,
        }, env.jwtSecret, { expiresIn: accessTokenTtlForRole(created.role) });
        const refreshToken = jwt.sign({ id: created.id }, env.jwtSecret, { expiresIn: '30d' });
        // Generate and queue the OTP before confirming registration.
        const otpInfo = await createOtp(created.email);
        await queueOtpEmail(created.email, otpInfo.code);
        console.info(`OTP email queued for ${created.email}`);
        return res.status(201).json({ data: { token: accessToken, accessToken, refreshToken, user: created, otpSent: true } });
    }
    catch (error) {
        next(error);
    }
});
router.post('/change-email', requireAuth, async (req, res, next) => {
    try {
        const email = req.body?.email?.toString().trim().toLowerCase();
        if (!email || email.length > 254 || !EMAIL_PATTERN.test(email)) {
            return res.status(400).json({ error: 'Enter a valid email address.' });
        }
        if (email === req.auth.email.trim().toLowerCase()) {
            return res.status(400).json({ error: 'Enter a different email address.' });
        }
        const exists = await query('SELECT id FROM users WHERE email = $1 LIMIT 1', [email]);
        if ((exists.rowCount ?? 0) > 0) {
            return res.status(409).json({ error: 'Email already registered.' });
        }
        const updated = await query(`UPDATE users SET email = $1, verified = false WHERE id = $2
       RETURNING id, name, email, phone, avatar, role, verified`, [email, req.auth.id]);
        if ((updated.rowCount ?? 0) === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        await revokeOtp(req.auth.email);
        const otp = await createOtp(email);
        await queueOtpEmail(email, otp.code);
        return res.json({ data: { user: updated.rows[0], otpSent: true } });
    }
    catch (error) {
        next(error);
    }
});
router.post('/refresh', async (req, res, next) => {
    try {
        const { refreshToken } = req.body;
        if (!refreshToken) {
            return res.status(400).json({ error: 'Refresh token is required.' });
        }
        const payload = jwt.verify(refreshToken, env.jwtSecret);
        if (!payload.id) {
            return res.status(401).json({ error: 'Invalid refresh token.' });
        }
        const result = await query('SELECT id, name, email, phone, avatar, role, verified, referral_code, wallet_balance FROM users WHERE id = $1 LIMIT 1', [payload.id]);
        const user = result.rows[0];
        if (!user) {
            return res.status(401).json({ error: 'Invalid refresh token.' });
        }
        const accessToken = jwt.sign({
            id: user.id,
            email: user.email,
            role: user.role,
            verified: user.verified,
        }, env.jwtSecret, { expiresIn: accessTokenTtlForRole(user.role) });
        const nextRefreshToken = jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: '30d' });
        return res.json({
            data: {
                token: accessToken,
                accessToken,
                refreshToken: nextRefreshToken,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    phone: user.phone,
                    avatar: user.avatar,
                    role: user.role,
                    verified: user.verified,
                },
            },
        });
    }
    catch (error) {
        next(error);
    }
});
router.post('/verify', requireAuth, async (req, res, next) => {
    try {
        const { code } = req.body;
        if (!code || code.trim() === '') {
            return res.status(400).json({ error: 'Verification code is required.' });
        }
        const normalizedCode = code.trim();
        if (!(await verifyOtp(req.auth.email, normalizedCode))) {
            return res.status(400).json({ error: 'Invalid verification code.' });
        }
        const result = await query(`UPDATE users
       SET verified = true
       WHERE id = $1
       RETURNING id, name, email, role, avatar, verified`, [req.auth.id]);
        if (result.rowCount === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        return res.json({ data: { user: result.rows[0] } });
    }
    catch (error) {
        next(error);
    }
});
router.post('/login', async (req, res, next) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required.' });
        }
        const result = await query('SELECT id, name, email, phone, avatar, password_hash, role, verified, referral_code, wallet_balance FROM users WHERE email = $1 LIMIT 1', [email.trim().toLowerCase()]);
        const user = result.rows[0];
        if (!user || !user.password_hash) {
            return res.status(401).json({ error: 'Invalid credentials.' });
        }
        const isValid = await bcrypt.compare(password, user.password_hash);
        if (!isValid) {
            return res.status(401).json({ error: 'Invalid credentials.' });
        }
        const accessToken = jwt.sign({
            id: user.id,
            email: user.email,
            role: user.role,
            verified: user.verified,
        }, env.jwtSecret, { expiresIn: accessTokenTtlForRole(user.role) });
        const refreshToken = jwt.sign({ id: user.id }, env.jwtSecret, { expiresIn: '30d' });
        return res.json({
            data: {
                token: accessToken,
                accessToken,
                refreshToken,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    phone: user.phone,
                    avatar: user.avatar,
                    role: user.role,
                    verified: user.verified,
                },
            },
        });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=auth.js.map