/**
 * cron.ts — StayNest scheduled background jobs
 *
 * Jobs:
 *  1. Check-in reminders     — daily 7 AM  — tenant + landlord
 *  2. Check-out reminders    — daily 8 AM  — tenant
 *  3. Stale booking alerts   — daily 6 PM  — landlord with pending >48h
 *  4. Unread message nudge   — every 2h    — users with unread >1h
 *  5. Weekly perf digest     — Mon 9 AM    — landlord email + push
 */
import cron from 'node-cron';
import { query } from '../db.js';
import { queueUserPush } from './queue.js';
import { sendAlertEmail } from './email.js';
import { refundExpiredBookingEscrows } from './finance_service.js';
// --- helpers ------------------------------------------------------------------
function fmt(date) {
    const d = new Date(date);
    return d.toLocaleDateString('en-KE', { weekday: 'short', day: 'numeric', month: 'short' });
}
// --- 1. Check-in reminders (daily 7 AM) --------------------------------------
async function sendCheckinReminders() {
    try {
        const res = await query(`SELECT b.id, b.check_in_date, b.tenant_id, b.landlord_id,
              p.title AS property_name,
              t.name  AS tenant_name
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       JOIN users      t ON t.id = b.tenant_id
       WHERE b.status = 'confirmed'
         AND b.check_in_date = CURRENT_DATE + 1`, []);
        for (const row of res.rows) {
            const dateStr = fmt(row.check_in_date);
            // Notify tenant
            await queueUserPush(row.tenant_id, 'Check-in Tomorrow!', `Your check-in at ${row.property_name} is tomorrow (${dateStr}). Get ready!`, { type: 'checkin_reminder', bookingId: row.id });
            // Notify landlord
            await queueUserPush(row.landlord_id, 'Tenant Arrives Tomorrow', `${row.tenant_name} checks in to ${row.property_name} tomorrow (${dateStr}).`, { type: 'checkin_landlord', bookingId: row.id });
        }
        console.log(`[cron] check-in reminders sent for ${res.rowCount} bookings`);
    }
    catch (err) {
        console.error('[cron] check-in reminders failed:', err);
    }
}
// --- 2. Check-out reminders (daily 8 AM) -------------------------------------
async function sendCheckoutReminders() {
    try {
        const res = await query(`SELECT b.id, b.check_out_date, b.tenant_id,
              p.title AS property_name
       FROM bookings b
       JOIN properties p ON p.id = b.property_id
       WHERE b.status = 'confirmed'
         AND b.check_out_date = CURRENT_DATE`, []);
        for (const row of res.rows) {
            await queueUserPush(row.tenant_id, 'Check-out Today', `Your check-out at ${row.property_name} is today. Safe travels!`, { type: 'checkout_reminder', bookingId: row.id });
        }
        console.log(`[cron] check-out reminders sent for ${res.rowCount} bookings`);
    }
    catch (err) {
        console.error('[cron] check-out reminders failed:', err);
    }
}
// --- 3. Stale pending bookings (daily 6 PM) -----------------------------------
async function sendStalePendingAlerts() {
    try {
        // Group by landlord
        const res = await query(`SELECT b.landlord_id, COUNT(*) AS pending_count
       FROM bookings b
       WHERE b.status = 'pending'
         AND b.created_at < now() - INTERVAL '48 hours'
       GROUP BY b.landlord_id`, []);
        for (const row of res.rows) {
            const n = parseInt(row.pending_count);
            await queueUserPush(row.landlord_id, '? Pending Booking Requests', `You have ${n} pending booking request${n === 1 ? '' : 's'} waiting for your response.`, { type: 'stale_pending' });
        }
        console.log(`[cron] stale-pending alerts sent to ${res.rowCount} landlords`);
    }
    catch (err) {
        console.error('[cron] stale-pending alerts failed:', err);
    }
}
async function refundExpiredBookings() {
    try {
        const refunded = await refundExpiredBookingEscrows();
        if (refunded > 0) {
            console.log(`[cron] refunded ${refunded} expired incomplete booking(s)`);
        }
    }
    catch (err) {
        console.error('[cron] expired booking refunds failed:', err);
    }
}
// --- 4. Unread message nudge (every 2 hours) ---------------------------------
async function sendUnreadMessageNudges() {
    try {
        // Users with unread messages older than 1 hour
        const res = await query(`SELECT m.to_user_id, COUNT(*) AS unread_count
       FROM messages m
       WHERE m.created_at < now() - INTERVAL '1 hour'
         AND m.created_at >= now() - INTERVAL '3 hours'
         AND NOT EXISTS (
           SELECT 1 FROM message_reads mr
           WHERE mr.message_id = m.id AND mr.user_id = m.to_user_id
         )
       GROUP BY m.to_user_id`, []);
        for (const row of res.rows) {
            const n = parseInt(row.unread_count);
            await queueUserPush(row.to_user_id, 'Unread Messages', `You have ${n} unread message${n === 1 ? '' : 's'} on StayNest.`, { type: 'unread_nudge' });
        }
        console.log(`[cron] unread nudges sent to ${res.rowCount} users`);
    }
    catch (err) {
        console.error('[cron] unread nudges failed:', err);
    }
}
// --- 5. Weekly landlord performance digest (Mon 9 AM) ------------------------
async function sendWeeklyPerformanceDigest() {
    try {
        const res = await query(`SELECT
         u.id      AS landlord_id,
         u.name    AS landlord_name,
         u.email   AS landlord_email,
         (
           SELECT COUNT(e.id)
           FROM engagement_events e
           JOIN properties p2 ON p2.id = e.property_id
           WHERE p2.landlord_id = u.id AND e.event_type = 'property_view' AND e.created_at > now() - INTERVAL '7 days'
         ) AS views,
         (
           SELECT COUNT(b.id)
           FROM bookings b
           JOIN properties p2 ON p2.id = b.property_id
           WHERE p2.landlord_id = u.id AND b.created_at > now() - INTERVAL '7 days'
         ) AS new_bookings,
         (
           SELECT COALESCE(SUM(b.total_price), 0)
           FROM bookings b
           JOIN properties p2 ON p2.id = b.property_id
           WHERE p2.landlord_id = u.id AND b.status = 'confirmed' AND b.created_at > now() - INTERVAL '7 days'
         ) AS revenue
       FROM users u
       WHERE EXISTS (SELECT 1 FROM properties p WHERE p.landlord_id = u.id)`, []);
        for (const row of res.rows) {
            const { landlord_id, landlord_name, landlord_email, views, new_bookings, revenue } = row;
            const subject = `Your Weekly StayNest Report`;
            const html = `
        <h2>Hello ${landlord_name},</h2>
        <p>Here's your StayNest performance for the past 7 days:</p>
        <table style="border-collapse:collapse; width:100%; max-width:400px;">
          <tr><td style="padding:8px;font-weight:bold;">Property Views</td><td style="padding:8px;">${views}</td></tr>
          <tr style="background:#f9fafb;"><td style="padding:8px;font-weight:bold;">New Bookings</td><td style="padding:8px;">${new_bookings}</td></tr>
          <tr><td style="padding:8px;font-weight:bold;">Booking Revenue</td><td style="padding:8px;">Ksh ${Number(revenue).toLocaleString()}</td></tr>
        </table>
        <p style="margin-top:24px;">Log in to <a href="https://staynest.top">StayNest</a> to view detailed analytics.</p>
        <p style="color:#9ca3af;font-size:12px;">You're receiving this because you have an active StayNest landlord account.</p>
      `;
            try {
                await sendAlertEmail(landlord_email, subject, `Views: ${views}, Bookings: ${new_bookings}, Revenue: Ksh ${revenue}`, html);
            }
            catch (emailErr) {
                console.error(`[cron] weekly digest email failed for ${landlord_email}:`, emailErr);
            }
            await queueUserPush(landlord_id, 'Weekly Report Ready', `Last 7 days: ${views} views, ${new_bookings} bookings, Ksh ${Number(revenue).toLocaleString()} revenue.`, { type: 'weekly_digest' });
        }
        console.log(`[cron] weekly digest sent to ${res.rowCount} landlords`);
    }
    catch (err) {
        console.error('[cron] weekly digest failed:', err);
    }
}
// --- Scheduler ----------------------------------------------------------------
export function startCronJobs() {
    // 1. Check-in reminders — daily 7:00 AM
    cron.schedule('0 7 * * *', sendCheckinReminders, { timezone: 'Africa/Nairobi' });
    // 2. Check-out reminders — daily 8:00 AM
    cron.schedule('0 8 * * *', sendCheckoutReminders, { timezone: 'Africa/Nairobi' });
    // 3. Stale pending alerts — daily 6:00 PM
    cron.schedule('0 18 * * *', sendStalePendingAlerts, { timezone: 'Africa/Nairobi' });
    cron.schedule('10 1 * * *', refundExpiredBookings, { timezone: 'Africa/Nairobi' });
    // 4. Unread message nudge — every 2 hours
    cron.schedule('0 */2 * * *', sendUnreadMessageNudges, { timezone: 'Africa/Nairobi' });
    // 5. Weekly landlord digest — every Monday 9:00 AM
    cron.schedule('0 9 * * 1', sendWeeklyPerformanceDigest, { timezone: 'Africa/Nairobi' });
    console.log('[cron] All scheduled jobs registered (timezone: Africa/Nairobi)');
}
//# sourceMappingURL=cron.js.map