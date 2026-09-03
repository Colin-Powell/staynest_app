import { Router } from 'express';
import { query } from '../db.js';
import { createOtp, queueOtpEmail, revokeOtp, sendAlertEmail, verifyOtp } from '../services/email.js';
import { requireAuth } from '../middleware/auth.js';
import rateLimit from 'express-rate-limit';
const router = Router();
const otpRateLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // Limit each IP to 5 requests per window
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Too many OTP requests, please try again later.',
    },
});
// Public: send OTP to an email address using a short-lived numeric code.
router.post('/send-otp', otpRateLimiter, async (req, res, next) => {
    try {
        const { email } = req.body;
        if (!email)
            return res.status(400).json({ error: 'Email is required.' });
        let code;
        let expiresAt;
        try {
            const otp = await createOtp(email);
            code = otp.code;
            expiresAt = otp.expiresAt;
        }
        catch (error) {
            const otpError = error;
            if (otpError.statusCode === 429) {
                if (otpError.retryAfterSeconds) {
                    res.setHeader('Retry-After', otpError.retryAfterSeconds);
                }
                return res.status(429).json({
                    error: otpError.message,
                    retryAfterSeconds: otpError.retryAfterSeconds,
                });
            }
            throw error;
        }
        await queueOtpEmail(email, code);
        console.info(`OTP email queued for ${email}`);
        return res.json({ data: { sent: true, expiresAt } });
    }
    catch (err) {
        next(err);
    }
});
router.post('/verify-otp', async (req, res, next) => {
    try {
        const { email, code } = req.body;
        if (!email || !code) {
            return res.status(400).json({ error: 'Email and code are required.' });
        }
        const normalizedEmail = email.trim().toLowerCase();
        if (!(await verifyOtp(normalizedEmail, code))) {
            return res.status(403).json({ error: 'Invalid verification code.' });
        }
        const result = await query(`UPDATE users SET verified = true WHERE email = $1 RETURNING id, name, email, role, avatar, verified`, [normalizedEmail]);
        if ((result.rowCount ?? 0) === 0) {
            return res.status(404).json({ error: 'User not found.' });
        }
        return res.json({ data: { user: result.rows[0], verified: true } });
    }
    catch (err) {
        next(err);
    }
});
router.post('/revoke-otp', requireAuth, async (req, res, next) => {
    try {
        const email = req.body?.email?.toString().trim().toLowerCase();
        if (!email || email !== req.auth.email.trim().toLowerCase()) {
            return res.status(403).json({ error: 'You can only revoke your own verification code.' });
        }
        await revokeOtp(email);
        return res.json({ data: { revoked: true } });
    }
    catch (err) {
        next(err);
    }
});
// Protected: send an arbitrary alert (admin or service use)
router.post('/alert', requireAuth, async (req, res, next) => {
    try {
        const { to, subject, text, html } = req.body;
        if (!to || !subject || !text)
            return res.status(400).json({ error: 'to, subject and text are required.' });
        await sendAlertEmail(to, subject, text, html);
        return res.json({ data: { sent: true } });
    }
    catch (err) {
        next(err);
    }
});
export default router;
//# sourceMappingURL=email.js.map