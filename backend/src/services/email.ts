import nodemailer from 'nodemailer';
import { env } from '../config.js';

const transporter = nodemailer.createTransport({
  host: env.smtpHost || 'smtp.gmail.com',
  port: env.smtpPort || 587,
  secure: env.smtpPort === 465,
  auth: {
    user: env.smtpUser || undefined,
    pass: env.smtpPass || undefined,
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
  const subject = 'Your StayNest verification code';
  const text = `Your verification code is ${code}. If you did not request this, please ignore.`;
  const html = `<p>Your verification code is <strong>${code}</strong>.</p><p>If you did not request this, please ignore this message.</p>`;

  const info = await transporter.sendMail({
    from: env.emailFrom,
    to,
    subject,
    text,
    html,
  });

  return info;
}

export async function sendAlertEmail(to: string, subject: string, text: string, html?: string) {
  const info = await transporter.sendMail({
    from: env.emailFrom,
    to,
    subject,
    text,
    html,
  });
  return info;
}

export default { sendOtpEmail, sendAlertEmail };
