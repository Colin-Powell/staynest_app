import { Router } from 'express';
import { sendOtpEmail, sendAlertEmail } from '../services/email.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// Public: send OTP to an email address (uses fixed code matching frontend mock)
router.post('/send-otp', async (req, res, next) => {
  try {
    const { email } = req.body as { email?: string };
    if (!email) return res.status(400).json({ error: 'Email is required.' });
    await sendOtpEmail(email, '624108');
    return res.json({ data: { sent: true } });
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
