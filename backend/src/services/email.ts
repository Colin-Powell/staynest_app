import nodemailer from 'nodemailer';
import { env } from '../config.js';

if (!env.smtpHost || !env.smtpUser || !env.smtpPass) {
  throw new Error('SMTP_HOST, SMTP_USER, and SMTP_PASS must be configured.');
}

const transporter = nodemailer.createTransport({
  host: env.smtpHost,
  port: env.smtpPort,
  secure: env.smtpPort === 465,
  auth: {
    user: env.smtpUser,
    pass: env.smtpPass,
  },
});

const otpStore = new Map<string, { code: string; expiresAt: number }>();

export function createOtp(email: string) {
  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = Date.now() + 10 * 60 * 1000;
  otpStore.set(email.trim().toLowerCase(), { code, expiresAt });
  return { code, expiresAt };
}

export function verifyOtp(email: string, code: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const record = otpStore.get(normalizedEmail);
  if (!record) return false;
  if (Date.now() > record.expiresAt) {
    otpStore.delete(normalizedEmail);
    return false;
  }
  const isValid = record.code === code.trim();
  if (isValid) otpStore.delete(normalizedEmail);
  return isValid;
}

export async function sendOtpEmail(to: string, code = '000000') {
  const subject = `StayNest: Welcome to your new home!`;
  const text = `Hi there,\n\nWelcome to StayNest! We are thrilled to have you on board.\n\nTo finish setting up your profile, please enter the following 6-digit confirmation number in the app:\n\n${code}\n\nIf you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.\n\nWarm regards,\nThe StayNest Team`;
  
  const html = `<p>Hi there,</p>
<p>Welcome to StayNest! We are thrilled to have you on board.</p>
<p>To finish setting up your profile, please enter the following 6-digit confirmation number in the app:</p>
<h2>${code}</h2>
<p>If you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.</p>
<p>Warm regards,<br>The StayNest Team</p>`;

  const info = await transporter.sendMail({
    from: env.emailFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });

  return info;
}

export async function sendAlertEmail(to: string, subject: string, text: string, html?: string) {
  const info = await transporter.sendMail({
    from: env.emailFrom || env.smtpUser,
    to,
    subject,
    text,
    html,
  });
  return info;
}

export default { sendOtpEmail, sendAlertEmail };
