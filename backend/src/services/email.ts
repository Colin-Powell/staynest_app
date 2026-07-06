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

export async function sendOtpEmail(to: string, code = '624108') {
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
