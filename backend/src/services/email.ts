import nodemailer from 'nodemailer';
import { env } from '../config.js';
import { emailQueue } from './emailQueue.js';
import { cache } from './cache.js';

const smtpConfigured = Boolean(env.smtpHost && env.smtpUser && env.smtpPass);

const transporter = smtpConfigured
  ? nodemailer.createTransport({
      host: env.smtpHost,
      port: env.smtpPort,
      secure: env.smtpPort === 465,
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 15_000,
      auth: {
        user: env.smtpUser,
        pass: env.smtpPass,
      },
    })
  : null;

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_TTL_SECONDS = OTP_TTL_MS / 1000;

type OtpRecord = { code: string; expiresAt: number };

function otpKey(email: string) {
  return `otp:${email.trim().toLowerCase()}`;
}

function ensureTransporter() {
  if (!transporter) {
    throw new Error('SMTP is not configured. Set SMTP_HOST, SMTP_USER, and SMTP_PASS to enable email delivery.');
  }
}

export async function createOtp(email: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const existingRaw = await cache.get(otpKey(normalizedEmail));
  const existing = existingRaw ? JSON.parse(existingRaw) as OtpRecord : null;
  if (existing && Date.now() < existing.expiresAt) {
    const error = new Error('A verification code is already active. Please wait until it expires before requesting another code.') as Error & { statusCode?: number; retryAfterSeconds?: number };
    error.statusCode = 429;
    error.retryAfterSeconds = Math.ceil((existing.expiresAt - Date.now()) / 1000);
    throw error;
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + OTP_TTL_MS;
  const reserved = await cache.setIfAbsent(
    otpKey(normalizedEmail),
    JSON.stringify({ code, expiresAt }),
    OTP_TTL_SECONDS,
  );
  if (!reserved) {
    const activeRaw = await cache.get(otpKey(normalizedEmail));
    const active = activeRaw ? JSON.parse(activeRaw) as OtpRecord : null;
    const error = new Error('A verification code is already active. Please wait until it expires before requesting another code.') as Error & { statusCode?: number; retryAfterSeconds?: number };
    error.statusCode = 429;
    error.retryAfterSeconds = active
      ? Math.ceil((active.expiresAt - Date.now()) / 1000)
      : OTP_TTL_SECONDS;
    throw error;
  }
  return { code, expiresAt };
}

export async function verifyOtp(email: string, code: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const raw = await cache.get(otpKey(normalizedEmail));
  const record = raw ? JSON.parse(raw) as OtpRecord : null;
  if (!record) return false;
  if (Date.now() > record.expiresAt) {
    await cache.del(otpKey(normalizedEmail));
    return false;
  }
  const isValid = record.code === code.trim();
  if (isValid) await cache.del(otpKey(normalizedEmail));
  return isValid;
}

export async function queueOtpEmail(to: string, code: string) {
  const normalizedEmail = to.trim().toLowerCase();
  await emailQueue.add(
    'otp-email',
    { to: normalizedEmail, code },
    {
      jobId: `otp-${normalizedEmail}-${code}`,
      attempts: 4,
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: { age: 15 * 60, count: 1000 },
      removeOnFail: { age: 24 * 60 * 60, count: 5000 },
    },
  );
}

export async function sendOtpEmail(to: string, code = '000000') {
  ensureTransporter();

  const subject = 'StayNest: Welcome to your new home!';
  const text = `Hi there,\n\nWelcome to StayNest! We are thrilled to have you on board.\n\nTo finish setting up your profile, please enter the following 6-digit confirmation number in the app:\n\n${code}\n\nIf you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.\n\nWarm regards,\nThe StayNest Team`;

  const html = `<p>Hi there,</p>
<p>Welcome to StayNest! We are thrilled to have you on board.</p>
<p>To finish setting up your profile, please enter the following 6-digit confirmation number in the app:</p>
<h2>${code}</h2>
<p>If you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.</p>
<p>Warm regards,<br>The StayNest Team</p>`;

  return transporter!.sendMail({
    from: env.emailFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });
}

export async function sendAlertEmail(to: string, subject: string, text: string, html?: string) {
  ensureTransporter();

  return transporter!.sendMail({
    from: env.emailFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });
}

export async function sendLandlordVerificationDecisionEmail(
  to: string,
  status: 'approved' | 'rejected',
  landlordName?: string,
  notes?: string,
) {
  if (!to) return null;

  const displayName = landlordName?.trim() || 'Landlord';
  const subject = status === 'approved'
    ? 'StayNest landlord verification approved'
    : 'StayNest landlord verification update';

  const text = status === 'approved'
    ? `Hi ${displayName},\n\nYour landlord verification has been approved. Your account is now verified and access to the landlord dashboard has been granted.\n\nYou can now continue managing properties and conversations from the dashboard.\n\n${notes ? `Admin note: ${notes}\n\n` : ''}Warm regards,\nThe StayNest Team`
    : `Hi ${displayName},\n\nYour landlord verification has been processed. ${notes ? `Reason: ${notes}` : 'Please review the required documentation and resubmit when ready.'}\n\nWarm regards,\nThe StayNest Team`;

  const html = status === 'approved'
    ? `<p>Hi ${displayName},</p><p>Your landlord verification has been approved.</p><p>Your account is now verified and access to the landlord dashboard has been granted.</p><p>You can now continue managing properties and conversations from the dashboard.</p>${notes ? `<p><strong>Admin note:</strong> ${notes}</p>` : ''}<p>Warm regards,<br>The StayNest Team</p>`
    : `<p>Hi ${displayName},</p><p>Your landlord verification has been processed.</p>${notes ? `<p><strong>Reason:</strong> ${notes}</p>` : '<p>Please review the required documentation and resubmit when ready.</p>'}<p>Warm regards,<br>The StayNest Team</p>`;

  return sendAlertEmail(to, subject, text, html);
}

export default { sendOtpEmail, sendAlertEmail, sendLandlordVerificationDecisionEmail };
