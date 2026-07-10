import { Router } from 'express';
import { query } from '../db.js';
import { createOtp, sendOtpEmail, sendAlertEmail, verifyOtp } from '../services/email.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Public: send OTP to an email address using a short-lived numeric code.
router.post('/send-otp', async (req, res, next) => {
  try {
    const { email } = req.body as { email?: string };
    if (!email) return res.status(400).json({ error: 'Email is required.' });

    const { code } = createOtp(email);
    await sendOtpEmail(email, code);
    return res.json({ data: { sent: true, code } });
  } catch (err) {
    next(err);
  }
});

router.post('/verify-otp', async (req, res, next) => {
  try {
    const { email, code } = req.body as { email?: string; code?: string };
    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required.' });
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (!verifyOtp(normalizedEmail, code)) {
      return res.status(403).json({ error: 'Invalid verification code.' });
    }

    const result = await query(
      `UPDATE users SET verified = true WHERE email = $1 RETURNING id, name, email, role, avatar, verified`,
      [normalizedEmail],
    );

    if ((result.rowCount ?? 0) === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    return res.json({ data: { user: result.rows[0], verified: true } });
  } catch (err) {
    next(err);
  }
});

// Protected: send an arbitrary alert (admin or service use)
router.post('/alert', requireAuth, async (req, res, next) => {
  try {
    const { to, subject, text, html } = req.body as { to?: string; subject?: string; text?: string; html?: string };
    if (!to || !subject || !text) return res.status(400).json({ error: 'to, subject and text are required.' });
    await sendAlertEmail(to, subject, text, html);
    return res.json({ data: { sent: true } });
  } catch (err) {
    next(err);
  }
});

export default router;
