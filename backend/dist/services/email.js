import nodemailer from 'nodemailer';
import { env } from '../config.js';
const smtpConfigured = Boolean(env.smtpHost && env.smtpUser && env.smtpPass);
const transporter = smtpConfigured
    ? nodemailer.createTransport({
        host: env.smtpHost,
        port: env.smtpPort,
        secure: env.smtpPort === 465,
        auth: {
            user: env.smtpUser,
            pass: env.smtpPass,
        },
    })
    : null;
const otpStore = new Map();
function ensureTransporter() {
    if (!transporter) {
        console.warn('SMTP is not configured; skipping email send. Set SMTP_HOST, SMTP_USER, and SMTP_PASS to enable email delivery.');
        return false;
    }
    return true;
}
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
    if (!ensureTransporter())
        return null;
    const subject = 'StayNest: Welcome to your new home!';
    const text = `Hi there,\n\nWelcome to StayNest! We are thrilled to have you on board.\n\nTo finish setting up your profile, please enter the following 6-digit confirmation number in the app:\n\n${code}\n\nIf you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.\n\nWarm regards,\nThe StayNest Team`;
    const html = `<p>Hi there,</p>
<p>Welcome to StayNest! We are thrilled to have you on board.</p>
<p>To finish setting up your profile, please enter the following 6-digit confirmation number in the app:</p>
<h2>${code}</h2>
<p>If you did not sign up for an account, please disregard this email. The confirmation number will automatically expire shortly.</p>
<p>Warm regards,<br>The StayNest Team</p>`;
    return transporter.sendMail({
        from: env.emailFrom || env.smtpUser,
        to,
        subject,
        text,
        html,
    });
}
export async function sendAlertEmail(to, subject, text, html) {
    if (!ensureTransporter())
        return null;
    return transporter.sendMail({
        from: env.emailFrom || env.smtpUser,
        to,
        subject,
        text,
        html,
    });
}
export async function sendLandlordVerificationDecisionEmail(to, status, landlordName, notes) {
    if (!to)
        return null;
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
//# sourceMappingURL=email.js.map