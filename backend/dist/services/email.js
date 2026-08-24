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
const otpStore = new Map();
export function createOtp(email) {
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000;
    otpStore.set(email.trim().toLowerCase(), { code, expiresAt });
    return { code, expiresAt };
}
export function verifyOtp(email, code) {
    const normalizedEmail = email.trim().toLowerCase();
    const record = otpStore.get(normalizedEmail);
    if (!record)
        return false;
    if (Date.now() > record.expiresAt) {
        otpStore.delete(normalizedEmail);
        return false;
    }
    const isValid = record.code === code.trim();
    if (isValid)
        otpStore.delete(normalizedEmail);
    return isValid;
}
export async function sendOtpEmail(to, code = '000000') {
    const subject = 'Your StayNest verification code';
    const text = `Your verification code is ${code}. If you did not request this, please ignore.`;
    const html = `<p>Your verification code is <strong>${code}</strong>.</p><p>If you did not request this, please ignore this message.</p>`;
    const info = await transporter.sendMail({
        from: env.emailFrom || env.smtpUser,
        to,
        subject,
        text,
        html,
    });
    return info;
}
export async function sendAlertEmail(to, subject, text, html) {
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
//# sourceMappingURL=email.js.map