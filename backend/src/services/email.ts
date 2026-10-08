import nodemailer from 'nodemailer';
import { randomUUID } from 'node:crypto';
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared email layout helpers
// ─────────────────────────────────────────────────────────────────────────────

function emailLayout(content: string, preheader = '') {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>StayNest</title>
<!--[if mso]><style>td{font-family:Arial,sans-serif!important}</style><![endif]-->
</head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;">
${preheader ? `<div style="display:none;max-height:0;overflow:hidden;">${preheader}&nbsp;‌&nbsp;‌&nbsp;</div>` : ''}
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F3F4F6;padding:32px 0;">
  <tr><td align="center">
    <table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#FFFFFF;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.07);">
      <!-- Header -->
      <tr>
        <td style="background:#10B981;padding:28px 40px;">
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td>
                <span style="font-size:22px;font-weight:800;color:#FFFFFF;letter-spacing:-0.5px;">StayNest</span>
                <span style="font-size:11px;color:rgba(255,255,255,0.7);margin-left:8px;vertical-align:middle;">for Students</span>
              </td>
            </tr>
          </table>
        </td>
      </tr>
      <!-- Body -->
      <tr><td style="padding:40px;">
        ${content}
      </td></tr>
      <!-- Footer -->
      <tr>
        <td style="background:#F9FAFB;padding:24px 40px;border-top:1px solid #E5E7EB;">
          <p style="margin:0;font-size:12px;color:#9CA3AF;line-height:1.6;">
            You are receiving this email because you have an account on StayNest.<br/>
            StayNest &middot; Student Housing Platform &middot; <a href="https://staynest.top" style="color:#10B981;text-decoration:none;">staynest.top</a>
          </p>
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body>
</html>`;
}

function ctaButton(label: string, href: string, color = '#10B981') {
  return `<table cellpadding="0" cellspacing="0" style="margin:24px 0;">
    <tr>
      <td style="background:${color};border-radius:10px;padding:0;">
        <a href="${href}" style="display:inline-block;padding:14px 32px;font-size:15px;font-weight:700;color:#FFFFFF;text-decoration:none;letter-spacing:0.2px;">${label}</a>
      </td>
    </tr>
  </table>`;
}

function statBox(label: string, value: string, accent = '#10B981') {
  return `<td style="padding:12px 16px;background:#F9FAFB;border-radius:10px;text-align:center;min-width:100px;">
    <div style="font-size:24px;font-weight:800;color:${accent};">${value}</div>
    <div style="font-size:11px;color:#6B7280;margin-top:4px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;">${label}</div>
  </td>`;
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP
// ─────────────────────────────────────────────────────────────────────────────

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

export async function revokeOtp(email: string) {
  await cache.del(otpKey(email));
}

export async function queueOtpEmail(to: string, code: string) {
  const normalizedEmail = to.trim().toLowerCase();
  console.info(`[OTP] adding email job for ${normalizedEmail}`);
  await emailQueue.add(
    'otp-email',
    { to: normalizedEmail, code },
    {
      jobId: `otp-${randomUUID()}`,
      attempts: 4,
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: { age: 15 * 60, count: 1000 },
      removeOnFail: { age: 24 * 60 * 60, count: 5000 },
    },
  );
}

export async function sendOtpEmail(to: string, code = '000000') {
  ensureTransporter();

  const subject = 'Your StayNest verification code';
  const text = `Hi there,\n\nWelcome to StayNest! Your 6-digit verification code is:\n\n${code}\n\nThis code expires in 10 minutes. If you did not request this, please ignore this email.\n\nWarm regards,\nThe StayNest Team`;

  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:26px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Welcome to StayNest! 🏠</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6B7280;line-height:1.6;">Thanks for joining. To finish setting up your account, enter the code below in the app:</p>
    <div style="background:#F0FDF4;border:2px dashed #10B981;border-radius:14px;padding:32px;text-align:center;margin:0 0 24px;">
      <div style="font-size:42px;font-weight:900;letter-spacing:12px;color:#111827;font-family:monospace;">${code}</div>
      <div style="font-size:12px;color:#9CA3AF;margin-top:8px;">Expires in 10 minutes</div>
    </div>
    <p style="margin:0;font-size:13px;color:#9CA3AF;line-height:1.6;">If you did not create a StayNest account, you can safely ignore this email.</p>
  `, `Your StayNest verification code is ${code}`);

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

// ─────────────────────────────────────────────────────────────────────────────
// Verification emails
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sends a targeted verification reminder email.
 * @param missingSteps - Array of human-readable step names (e.g. ['Selfie with ID', 'Lease Document'])
 */
export async function sendVerificationReminderEmail(
  to: string,
  userName: string,
  missingSteps: string[],
  reminderStage: number,
) {
  if (!to) return null;
  ensureTransporter();

  const firstName = (userName?.trim() || 'there').split(' ')[0];
  const totalSteps = 4; // ID front, ID back, selfie, lease
  const completedSteps = totalSteps - missingSteps.length;

  const subject = reminderStage >= 2
    ? `⏰ Final reminder — complete your StayNest host verification`
    : `📋 You're ${completedSteps}/${totalSteps} steps done — finish verifying your StayNest account`;

  const urgencyText = reminderStage >= 2
    ? `<p style="margin:0 0 16px;padding:14px 18px;background:#FEF3C7;border-left:4px solid #F59E0B;border-radius:0 8px 8px 0;font-size:14px;color:#92400E;font-weight:600;">⚠️ This is your final reminder. Complete your verification to keep your host application active.</p>`
    : '';

  const missingList = missingSteps.map(step => `
    <tr>
      <td style="padding:10px 0;border-bottom:1px solid #F3F4F6;">
        <table cellpadding="0" cellspacing="0" width="100%"><tr>
          <td width="28" style="vertical-align:middle;">
            <div style="width:22px;height:22px;background:#FEF3C7;border-radius:50%;text-align:center;line-height:22px;font-size:12px;">⚠️</div>
          </td>
          <td style="vertical-align:middle;padding-left:12px;font-size:14px;color:#374151;font-weight:600;">${step}</td>
          <td align="right" style="vertical-align:middle;">
            <span style="font-size:11px;color:#F59E0B;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;">Required</span>
          </td>
        </tr></table>
      </td>
    </tr>
  `).join('');

  const completedLabel = completedSteps > 0
    ? `<p style="margin:0 0 8px;font-size:14px;color:#10B981;font-weight:600;">✅ ${completedSteps} step${completedSteps > 1 ? 's' : ''} already completed — great progress!</p>`
    : '';

  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Hi ${firstName}, you're almost there! 🏡</h2>
    <p style="margin:0 0 20px;font-size:15px;color:#6B7280;line-height:1.6;">You started your StayNest host verification but haven't finished it yet. Complete the remaining steps below to get your badge and start receiving bookings.</p>
    ${urgencyText}
    ${completedLabel}
    <p style="margin:0 0 12px;font-size:14px;font-weight:700;color:#111827;">Still needed from you:</p>
    <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
      ${missingList}
    </table>
    <div style="background:#F0FDF4;border-radius:12px;padding:20px;margin:0 0 24px;">
      <p style="margin:0;font-size:13px;color:#065F46;line-height:1.6;">
        <strong>Why verify?</strong> Verified landlords get a trust badge, appear higher in search results, and receive <strong>3× more booking requests</strong> than unverified landlords.
      </p>
    </div>
    ${ctaButton('Complete Verification Now', 'https://staynest.top/verification_center')}
    <p style="margin:16px 0 0;font-size:12px;color:#9CA3AF;">The process takes less than 5 minutes. Your documents are stored securely.</p>
  `, `You have ${missingSteps.length} steps left on your StayNest host verification`);

  const text = `Hi ${firstName},\n\nYou started your StayNest host verification but still have steps to complete.\n\nMissing steps:\n${missingSteps.map(s => `• ${s}`).join('\n')}\n\nComplete your verification at: https://staynest.top/verification_center\n\nWarm regards,\nThe StayNest Team`;

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
  ensureTransporter();

  const displayName = (landlordName?.trim() || 'Landlord').split(' ')[0];

  if (status === 'approved') {
    const subject = '🎉 Congratulations — You are now a verified StayNest host!';
    const html = emailLayout(`
      <div style="text-align:center;margin:0 0 32px;">
        <div style="display:inline-block;background:#D1FAE5;border-radius:50%;padding:20px;margin-bottom:16px;">
          <span style="font-size:48px;">✅</span>
        </div>
        <h2 style="margin:0 0 8px;font-size:26px;font-weight:800;color:#111827;letter-spacing:-0.5px;">You're Verified, ${displayName}!</h2>
        <p style="margin:0;font-size:15px;color:#6B7280;">Your StayNest host application has been approved.</p>
      </div>
      <div style="background:#F0FDF4;border:1px solid #A7F3D0;border-radius:12px;padding:24px;margin:0 0 24px;">
        <p style="margin:0 0 12px;font-size:14px;font-weight:700;color:#065F46;">What you can do now:</p>
        <table width="100%" cellpadding="0" cellspacing="0">
          <tr><td style="padding:8px 0;font-size:14px;color:#374151;">✅ &nbsp; List properties on StayNest</td></tr>
          <tr><td style="padding:8px 0;font-size:14px;color:#374151;">✅ &nbsp; Receive verified-host badge on all listings</td></tr>
          <tr><td style="padding:8px 0;font-size:14px;color:#374151;">✅ &nbsp; Accept bookings and receive payments</td></tr>
          <tr><td style="padding:8px 0;font-size:14px;color:#374151;">✅ &nbsp; Access full landlord dashboard</td></tr>
        </table>
      </div>
      ${notes ? `<p style="margin:0 0 16px;font-size:14px;color:#374151;padding:14px;background:#F9FAFB;border-radius:8px;"><strong>Note from the team:</strong> ${notes}</p>` : ''}
      ${ctaButton('Go to My Dashboard', 'https://staynest.top/landlord')}
    `, `Your StayNest host application has been approved`);

    const text = `Hi ${displayName},\n\nGreat news! Your StayNest host application has been approved.\n\nYou can now list properties, receive bookings, and access your landlord dashboard.\n\nLog in at https://staynest.top\n\nWarm regards,\nThe StayNest Team`;
    return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
  }

  // Rejected
  const subject = 'Update on your StayNest host verification';
  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Hi ${displayName}, we need a little more from you</h2>
    <p style="margin:0 0 20px;font-size:15px;color:#6B7280;line-height:1.6;">We reviewed your host application and were unable to approve it at this time.</p>
    ${notes
      ? `<div style="background:#FEF2F2;border:1px solid #FECACA;border-radius:12px;padding:20px;margin:0 0 24px;">
           <p style="margin:0 0 8px;font-size:14px;font-weight:700;color:#991B1B;">Reason:</p>
           <p style="margin:0;font-size:14px;color:#7F1D1D;line-height:1.6;">${notes}</p>
         </div>`
      : `<p style="margin:0 0 24px;font-size:14px;color:#6B7280;">Please review the required documentation and resubmit when ready.</p>`
    }
    <div style="background:#F9FAFB;border-radius:12px;padding:20px;margin:0 0 24px;">
      <p style="margin:0 0 12px;font-size:14px;font-weight:700;color:#374151;">Common reasons for rejection:</p>
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr><td style="padding:6px 0;font-size:13px;color:#6B7280;">• Blurry or unreadable ID photos</td></tr>
        <tr><td style="padding:6px 0;font-size:13px;color:#6B7280;">• Selfie does not clearly show your face alongside the ID</td></tr>
        <tr><td style="padding:6px 0;font-size:13px;color:#6B7280;">• Lease / authorization document is expired or incomplete</td></tr>
      </table>
    </div>
    ${ctaButton('Resubmit Verification', 'https://staynest.top/verification_center', '#6366F1')}
    <p style="margin:16px 0 0;font-size:12px;color:#9CA3AF;">If you believe this is a mistake, please contact our support team.</p>
  `, `Update on your StayNest host verification`);

  const text = `Hi ${displayName},\n\nYour StayNest host application could not be approved at this time.${notes ? `\n\nReason: ${notes}` : ''}\n\nPlease review and resubmit at: https://staynest.top/verification_center\n\nWarm regards,\nThe StayNest Team`;
  return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking event emails
// ─────────────────────────────────────────────────────────────────────────────

export async function sendBookingConfirmationEmail(
  to: string,
  tenantName: string,
  propertyName: string,
  checkIn: string,
  checkOut: string,
  totalAmount: number,
  bookingId: string,
) {
  if (!to) return null;
  ensureTransporter();

  const firstName = (tenantName?.trim() || 'there').split(' ')[0];
  const subject = `📋 Booking confirmed — ${propertyName}`;
  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Your booking is confirmed! 🎉</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6B7280;line-height:1.6;">Hi ${firstName}, you're all set. Here are your booking details:</p>
    <div style="background:#F0FDF4;border:1px solid #A7F3D0;border-radius:14px;padding:24px;margin:0 0 24px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr><td style="padding:8px 0;border-bottom:1px solid #D1FAE5;">
          <span style="font-size:13px;color:#6B7280;font-weight:600;">Property</span><br/>
          <span style="font-size:15px;font-weight:700;color:#111827;">${propertyName}</span>
        </td></tr>
        <tr><td style="padding:8px 0;border-bottom:1px solid #D1FAE5;">
          <table width="100%" cellpadding="0" cellspacing="0"><tr>
            <td><span style="font-size:13px;color:#6B7280;font-weight:600;">Check-in</span><br/><span style="font-size:15px;font-weight:700;color:#111827;">${checkIn}</span></td>
            <td align="right"><span style="font-size:13px;color:#6B7280;font-weight:600;">Check-out</span><br/><span style="font-size:15px;font-weight:700;color:#111827;">${checkOut}</span></td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:8px 0;">
          <span style="font-size:13px;color:#6B7280;font-weight:600;">Amount Paid</span><br/>
          <span style="font-size:20px;font-weight:800;color:#10B981;">Ksh ${Number(totalAmount).toLocaleString()}</span>
        </td></tr>
      </table>
    </div>
    ${ctaButton('View My Booking', `https://staynest.top/bookings/${bookingId}`)}
    <p style="margin:16px 0 0;font-size:12px;color:#9CA3AF;">Booking ID: ${bookingId}</p>
  `, `Your booking at ${propertyName} is confirmed`);

  const text = `Hi ${firstName},\n\nYour booking at ${propertyName} is confirmed.\n\nCheck-in: ${checkIn}\nCheck-out: ${checkOut}\nAmount paid: Ksh ${Number(totalAmount).toLocaleString()}\n\nView booking: https://staynest.top/bookings/${bookingId}\n\nWarm regards,\nThe StayNest Team`;
  return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
}

export async function sendNewBookingLandlordEmail(
  to: string,
  landlordName: string,
  tenantName: string,
  propertyName: string,
  checkIn: string,
  checkOut: string,
  totalAmount: number,
  bookingId: string,
) {
  if (!to) return null;
  ensureTransporter();

  const firstName = (landlordName?.trim() || 'there').split(' ')[0];
  const subject = `🔔 New booking request — ${propertyName}`;
  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">New booking for ${propertyName}!</h2>
    <p style="margin:0 0 24px;font-size:15px;color:#6B7280;line-height:1.6;">Hi ${firstName}, <strong>${tenantName}</strong> has placed a booking request for one of your properties.</p>
    <div style="background:#F9FAFB;border-radius:14px;padding:24px;margin:0 0 24px;">
      <table width="100%" cellpadding="0" cellspacing="0">
        <tr><td style="padding:8px 0;border-bottom:1px solid #E5E7EB;">
          <span style="font-size:13px;color:#6B7280;font-weight:600;">Tenant</span><br/>
          <span style="font-size:15px;font-weight:700;color:#111827;">${tenantName}</span>
        </td></tr>
        <tr><td style="padding:8px 0;border-bottom:1px solid #E5E7EB;">
          <table width="100%" cellpadding="0" cellspacing="0"><tr>
            <td><span style="font-size:13px;color:#6B7280;font-weight:600;">Check-in</span><br/><span style="font-size:15px;font-weight:700;color:#111827;">${checkIn}</span></td>
            <td align="right"><span style="font-size:13px;color:#6B7280;font-weight:600;">Check-out</span><br/><span style="font-size:15px;font-weight:700;color:#111827;">${checkOut}</span></td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:8px 0;">
          <span style="font-size:13px;color:#6B7280;font-weight:600;">Revenue</span><br/>
          <span style="font-size:20px;font-weight:800;color:#10B981;">Ksh ${Number(totalAmount).toLocaleString()}</span>
        </td></tr>
      </table>
    </div>
    ${ctaButton('View Booking Details', `https://staynest.top/landlord/bookings/${bookingId}`)}
  `, `New booking request from ${tenantName}`);

  const text = `Hi ${firstName},\n\n${tenantName} has booked ${propertyName}.\n\nCheck-in: ${checkIn}\nCheck-out: ${checkOut}\nRevenue: Ksh ${Number(totalAmount).toLocaleString()}\n\nView: https://staynest.top/landlord/bookings/${bookingId}\n\nWarm regards,\nThe StayNest Team`;
  return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
}

export async function sendPropertyApprovedEmail(
  to: string,
  landlordName: string,
  propertyTitle: string,
  propertyId: string,
) {
  if (!to) return null;
  ensureTransporter();

  const firstName = (landlordName?.trim() || 'there').split(' ')[0];
  const subject = `✅ Your listing "${propertyTitle}" is now live on StayNest!`;
  const html = emailLayout(`
    <h2 style="margin:0 0 8px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Your listing is live! 🎉</h2>
    <p style="margin:0 0 20px;font-size:15px;color:#6B7280;line-height:1.6;">Hi ${firstName}, your property <strong>"${propertyTitle}"</strong> has been reviewed and approved. Students can now discover and book it on StayNest.</p>
    <div style="background:#F0FDF4;border-radius:12px;padding:20px;margin:0 0 24px;">
      <p style="margin:0;font-size:14px;color:#065F46;line-height:1.6;">
        💡 <strong>Pro tip:</strong> Add high-quality photos and keep your availability up to date to get more bookings.
      </p>
    </div>
    ${ctaButton('View My Listing', `https://staynest.top/properties/${propertyId}`)}
    <table cellpadding="0" cellspacing="0" style="margin:8px 0 0;">
      <tr>
        <td>
          <a href="https://staynest.top/landlord" style="display:inline-block;padding:12px 24px;font-size:14px;font-weight:600;color:#10B981;text-decoration:none;border:2px solid #10B981;border-radius:10px;">Go to Dashboard</a>
        </td>
      </tr>
    </table>
  `, `Your listing "${propertyTitle}" is now live`);

  const text = `Hi ${firstName},\n\nYour property "${propertyTitle}" has been approved and is now live on StayNest.\n\nView listing: https://staynest.top/properties/${propertyId}\n\nWarm regards,\nThe StayNest Team`;
  return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly landlord digest
// ─────────────────────────────────────────────────────────────────────────────

export async function sendWeeklyLandlordDigestEmail(
  to: string,
  landlordName: string,
  stats: {
    views: number;
    newBookings: number;
    revenue: number;
    activeListings: number;
    pendingBookings: number;
    averageRating?: number;
  },
) {
  if (!to) return null;
  ensureTransporter();

  const firstName = (landlordName?.trim() || 'Landlord').split(' ')[0];
  const subject = `📊 Your StayNest weekly report — ${new Date().toLocaleDateString('en-KE', { weekday: 'long', day: 'numeric', month: 'long' })}`;

  const ratingDisplay = stats.averageRating
    ? `<span style="color:#F59E0B;">★</span> ${stats.averageRating.toFixed(1)}`
    : 'No ratings yet';

  const pendingAlert = stats.pendingBookings > 0
    ? `<div style="background:#FEF3C7;border-left:4px solid #F59E0B;border-radius:0 8px 8px 0;padding:14px 18px;margin:0 0 20px;">
         <p style="margin:0;font-size:14px;color:#92400E;font-weight:600;">⚠️ You have <strong>${stats.pendingBookings} pending booking${stats.pendingBookings > 1 ? 's' : ''}</strong> waiting for your response. Act quickly to avoid missing out!</p>
       </div>`
    : '';

  const html = emailLayout(`
    <h2 style="margin:0 0 4px;font-size:24px;font-weight:800;color:#111827;letter-spacing:-0.5px;">Hi ${firstName}, here's your week 👋</h2>
    <p style="margin:0 0 24px;font-size:14px;color:#9CA3AF;">Performance summary for the last 7 days</p>
    ${pendingAlert}
    <!-- Stats grid -->
    <table width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;border-spacing:8px;">
      <tr>
        ${statBox('Property Views', String(stats.views))}
        <td width="8"></td>
        ${statBox('New Bookings', String(stats.newBookings))}
        <td width="8"></td>
        ${statBox('Revenue (Ksh)', Number(stats.revenue).toLocaleString(), '#6366F1')}
      </tr>
      <tr><td colspan="5" height="8"></td></tr>
      <tr>
        ${statBox('Active Listings', String(stats.activeListings), '#0EA5E9')}
        <td width="8"></td>
        ${statBox('Pending Bookings', String(stats.pendingBookings), stats.pendingBookings > 0 ? '#F59E0B' : '#10B981')}
        <td width="8"></td>
        ${statBox('Avg Rating', ratingDisplay, '#F59E0B')}
      </tr>
    </table>
    <div style="background:#F9FAFB;border-radius:12px;padding:20px;margin:0 0 24px;">
      <p style="margin:0 0 8px;font-size:13px;font-weight:700;color:#374151;">💡 Grow faster this week:</p>
      <ul style="margin:0;padding-left:20px;font-size:13px;color:#6B7280;line-height:1.8;">
        <li>Add professional photos to listings with no bookings</li>
        <li>Respond to booking requests within 2 hours for better ranking</li>
        <li>Keep your availability calendar updated to reduce missed bookings</li>
      </ul>
    </div>
    <table width="100%" cellpadding="0" cellspacing="0">
      <tr>
        <td style="padding-right:8px;">
          ${ctaButton('View Dashboard', 'https://staynest.top/landlord')}
        </td>
        <td>
          <a href="https://staynest.top/landlord/bookings" style="display:inline-block;padding:14px 24px;font-size:14px;font-weight:700;color:#10B981;text-decoration:none;border:2px solid #10B981;border-radius:10px;margin-top:24px;">Manage Bookings</a>
        </td>
      </tr>
    </table>
  `, `Your StayNest weekly performance summary is ready`);

  const text = `Hi ${firstName},\n\nYour StayNest weekly report:\n• Views: ${stats.views}\n• New Bookings: ${stats.newBookings}\n• Revenue: Ksh ${Number(stats.revenue).toLocaleString()}\n• Active Listings: ${stats.activeListings}\n• Pending Bookings: ${stats.pendingBookings}\n\nView dashboard: https://staynest.top/landlord\n\nWarm regards,\nThe StayNest Team`;

  return transporter!.sendMail({ from: env.emailFrom || env.smtpUser, to, subject, text, html });
}

export default {
  sendOtpEmail,
  sendAlertEmail,
  sendLandlordVerificationDecisionEmail,
  sendVerificationReminderEmail,
  sendBookingConfirmationEmail,
  sendNewBookingLandlordEmail,
  sendPropertyApprovedEmail,
  sendWeeklyLandlordDigestEmail,
};
