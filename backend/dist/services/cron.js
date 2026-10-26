/**
 * cron.ts — StayNest scheduled background jobs
 *
 * Jobs:
 *  1. Check-in reminders     — daily 7 AM  — tenant + landlord
 *  2. Check-out reminders    — daily 8 AM  — tenant
 *  3. Stale booking alerts   — daily 6 PM  — landlord with pending >48h
 *  4. Unread message nudge   — every 2h    — users with unread >1h
 *  5. Weekly perf digest     — Mon 9 AM    — landlord email + push
 *  6. Host application reminders — hourly — draft verifications with personalized step tracking
 */
import cron from 'node-cron';
import { query } from '../db.js';
import { queueUserPush } from './queue.js';
import { sendVerificationReminderEmail, queueOtpReminderEmail, sendWeeklyLandlordDigestEmail, sendDailyListingDigestEmail, sendPersonalizedPromotionEmail, } from './email.js';
import { refundExpiredBookingEscrows } from './finance_service.js';
const hostReminderFirstHours = Math.max(1, Number.parseInt(process.env.HOST_REMINDER_FIRST_HOURS ?? '24', 10) || 24);
const hostReminderSecondHours = Math.max(hostReminderFirstHours + 1, Number.parseInt(process.env.HOST_REMINDER_SECOND_HOURS ?? '72', 10) || 72);
// --- helpers ------------------------------------------------------------------
function fmt(date) {
    const d = new Date(date);
    return d.toLocaleDateString('en-KE', { weekday: 'short', day: 'numeric', month: 'short' });
}
/**
 * Resolves the human-readable labels for missing verification steps from a
 * partially-completed `documents` JSONB object.
 */
function getMissingVerificationSteps(documents) {
    const docs = documents ?? {};
    const missing = [];
    if (!docs['id_photo_front'])
        missing.push('National ID (Front)');
    if (!docs['id_photo_back'])
        missing.push('National ID (Back)');
    if (!docs['selfie'])
        missing.push('Selfie with ID');
    if (!docs['lease_agreement'])
        missing.push('Ownership / Authorization Document');
    return missing;
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
            await queueUserPush(row.landlord_id, '⏳ Pending Booking Requests', `You have ${n} pending booking request${n === 1 ? '' : 's'} waiting for your response.`, { type: 'stale_pending' });
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
// --- 5. Unanswered property inquiry nudge (once, after 30 minutes) -----------
async function sendLandlordInquiryReminders() {
    try {
        const due = await query(`WITH due_conversations AS (
         SELECT mc.id AS conversation_id,
                p.landlord_id,
                p.id AS property_id,
                tenant_message.from_user_id AS tenant_id
         FROM message_conversations mc
         JOIN properties p ON p.id = mc.property_id
         JOIN users landlord ON landlord.id = p.landlord_id
         JOIN LATERAL (
           SELECT m.from_user_id, m.created_at
           FROM messages m
           JOIN users tenant ON tenant.id = m.from_user_id
           WHERE m.conversation_id = mc.id
             AND m.from_user_id <> p.landlord_id
             AND btrim(m.text) <> ''
             AND (tenant.role = 'tenant' OR 'tenant' = ANY(tenant.roles))
           ORDER BY m.created_at, m.id
           LIMIT 1
         ) tenant_message ON true
         WHERE mc.context_type = 'property'
           AND mc.landlord_response_reminder_sent_at IS NULL
           AND tenant_message.created_at <= now() - INTERVAL '30 minutes'
           AND NOT EXISTS (
             SELECT 1 FROM messages landlord_reply
             WHERE landlord_reply.conversation_id = mc.id
               AND landlord_reply.from_user_id = p.landlord_id
               AND landlord_reply.created_at > tenant_message.created_at
               AND btrim(landlord_reply.text) <> ''
           )
           AND landlord.settings->>'push' IS DISTINCT FROM 'false'
           AND landlord.settings #>> '{notifications,push_messages}' IS DISTINCT FROM 'false'
         ORDER BY tenant_message.created_at
         FOR UPDATE OF mc SKIP LOCKED
         LIMIT 100
       )
       UPDATE message_conversations mc
       SET landlord_response_reminder_sent_at = now()
       FROM due_conversations due
       WHERE mc.id = due.conversation_id
       RETURNING due.conversation_id, due.landlord_id, due.property_id, due.tenant_id`, []);
        for (const conversation of due.rows) {
            try {
                await queueUserPush(conversation.landlord_id, 'A prospective tenant is waiting', 'A tenant is waiting for your reply about one of your properties.', {
                    type: 'landlord_inquiry_reminder',
                    conversationId: conversation.conversation_id,
                    propertyId: conversation.property_id,
                });
            }
            catch (error) {
                console.error(`[cron] landlord inquiry reminder failed for conversationId=${conversation.conversation_id}:`, error);
                await query(`UPDATE message_conversations
           SET landlord_response_reminder_sent_at = NULL
           WHERE id = $1`, [conversation.conversation_id]);
            }
        }
        console.log(`[cron] landlord inquiry reminders queued for ${due.rowCount} conversations`);
    }
    catch (error) {
        console.error('[cron] landlord inquiry reminders failed:', error);
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
         ) AS revenue,
         (
           SELECT COUNT(p2.id)
           FROM properties p2
           WHERE p2.landlord_id = u.id AND COALESCE(p2.status, 'pending_review') = 'approved'
         ) AS active_listings,
         (
           SELECT COUNT(b.id)
           FROM bookings b
           JOIN properties p2 ON p2.id = b.property_id
           WHERE p2.landlord_id = u.id AND b.status = 'pending'
         ) AS pending_bookings,
         (
           SELECT ROUND(AVG(p2.average_rating)::numeric, 1)
           FROM properties p2
           WHERE p2.landlord_id = u.id AND p2.average_rating > 0
         ) AS average_rating
       FROM users u
       WHERE EXISTS (SELECT 1 FROM properties p WHERE p.landlord_id = u.id)
         AND u.email IS NOT NULL`, []);
        for (const row of res.rows) {
            const { landlord_id, landlord_name, landlord_email, views, new_bookings, revenue, active_listings, pending_bookings, average_rating, } = row;
            // Send rich email
            try {
                await sendWeeklyLandlordDigestEmail(landlord_email, landlord_name, {
                    views: Number(views) || 0,
                    newBookings: Number(new_bookings) || 0,
                    revenue: Number(revenue) || 0,
                    activeListings: Number(active_listings) || 0,
                    pendingBookings: Number(pending_bookings) || 0,
                    averageRating: average_rating ? Number(average_rating) : undefined,
                });
            }
            catch (emailErr) {
                console.error(`[cron] weekly digest email failed for ${landlord_email}:`, emailErr);
            }
            // Push notification
            const pendingNote = Number(pending_bookings) > 0
                ? ` · ${pending_bookings} pending`
                : '';
            await queueUserPush(landlord_id, ' Weekly Report Ready', `Last 7 days: ${views} views, ${new_bookings} bookings, Ksh ${Number(revenue).toLocaleString()} revenue${pendingNote}.`, { type: 'weekly_digest' });
        }
        console.log(`[cron] weekly digest sent to ${res.rowCount} landlords`);
    }
    catch (err) {
        console.error('[cron] weekly digest failed:', err);
    }
}
// --- Email verification follow-ups (1 hour and 24 hours after start) ---------
async function sendOtpVerificationReminders() {
    try {
        const due = await query(`WITH due_users AS (
         SELECT id, email, email_verification_reminder_stage
         FROM users
         WHERE verified = false
           AND (
             (email_verification_reminder_stage = 0
               AND email_verification_started_at <= now() - INTERVAL '1 hour')
             OR (email_verification_reminder_stage = 1
               AND email_verification_reminder_sent_at <= now() - INTERVAL '23 hours')
           )
         ORDER BY email_verification_started_at
         FOR UPDATE SKIP LOCKED
         LIMIT 100
       )
       UPDATE users u
       SET email_verification_reminder_stage = due_users.email_verification_reminder_stage + 1,
           email_verification_reminder_sent_at = now()
       FROM due_users
       WHERE u.id = due_users.id
       RETURNING u.id, u.email, u.email_verification_reminder_stage AS reminder_stage`, []);
        for (const user of due.rows) {
            try {
                await queueOtpReminderEmail(user.id, user.email, Number(user.reminder_stage));
            }
            catch (queueError) {
                console.error(`[cron] OTP reminder queue failed for userId=${user.id}:`, queueError);
                const stage = Number(user.reminder_stage);
                await query(`UPDATE users
           SET email_verification_reminder_stage = $2 - 1,
               email_verification_reminder_sent_at = CASE
                 WHEN $2 = 1 THEN NULL
                 ELSE now() - INTERVAL '23 hours'
               END
           WHERE id = $1 AND email_verification_reminder_stage = $2`, [user.id, stage]);
            }
        }
        console.log(`[cron] OTP verification reminders queued for ${due.rowCount} users`);
    }
    catch (err) {
        console.error('[cron] OTP verification reminders failed:', err);
    }
}
// --- 6. Host application reminders (24h and 72h after last saved progress) ---
async function sendHostApplicationReminders() {
    try {
        // Atomically advance reminder_stage and return the user's documents + email
        const due = await query(`WITH due_applications AS (
         SELECT v.id, v.user_id, v.reminder_stage, v.documents
         FROM verifications v
         WHERE v.status = 'draft'
           AND ((v.reminder_stage = 0 AND v.updated_at <= now() - ($1 * INTERVAL '1 hour'))
             OR (v.reminder_stage = 1 AND v.reminder_sent_at <= now() - (($2 - $1) * INTERVAL '1 hour')))
         ORDER BY v.updated_at
         FOR UPDATE SKIP LOCKED
         LIMIT 100
       )
       UPDATE verifications v
       SET reminder_stage = due_applications.reminder_stage + 1,
           reminder_sent_at = now(),
           updated_at = now()
       FROM due_applications
       WHERE v.id = due_applications.id
       RETURNING v.id, v.user_id, v.reminder_stage, due_applications.documents`, [hostReminderFirstHours, hostReminderSecondHours]);
        for (const application of due.rows) {
            const { id: verificationId, user_id: userId, reminder_stage: newStage, documents } = application;
            const isSecondReminder = newStage >= 2;
            // Resolve missing steps
            const docsMap = (typeof documents === 'string' ? JSON.parse(documents) : documents) ?? {};
            const missingSteps = getMissingVerificationSteps(docsMap);
            // Look up user email + name
            let userEmail = null;
            let userName = 'there';
            try {
                const userRes = await query('SELECT email, name FROM users WHERE id = $1 LIMIT 1', [userId]);
                if (userRes.rows[0]) {
                    userEmail = userRes.rows[0].email;
                    userName = userRes.rows[0].name || 'there';
                }
            }
            catch (_) {
                // continue — push still works without email
            }
            // Push notification with step info
            const stepLabel = missingSteps.length > 0
                ? `${missingSteps.length} step${missingSteps.length > 1 ? 's' : ''} remaining: ${missingSteps.slice(0, 2).join(', ')}${missingSteps.length > 2 ? '...' : ''}`
                : 'Almost done — submit your verification';
            await queueUserPush(userId, isSecondReminder ? ' Final reminder: Finish host verification' : '📋 Finish your host verification', stepLabel, {
                type: 'host_verification_reminder',
                verificationId,
                reminderStage: String(newStage),
            });
            // Send targeted email if we have an address
            if (userEmail && missingSteps.length > 0) {
                try {
                    await sendVerificationReminderEmail(userEmail, userName, missingSteps, newStage);
                }
                catch (emailErr) {
                    console.error(`[cron] verification reminder email failed for userId=${userId}:`, emailErr);
                }
            }
        }
        console.log(`[cron] host verification reminders queued for ${due.rowCount} applications`);
    }
    catch (err) {
        console.error('[cron] host verification reminders failed:', err);
    }
}
// --- 7. Daily listing digest (10 AM EAT) -------------------------------------
async function sendDailyListingAlerts() {
    const lockRes = await query(`SELECT pg_try_advisory_lock(7001) AS locked`, []);
    if (!lockRes.rows[0]?.locked)
        return;
    try {
        const tenants = await query(`SELECT u.id, u.name, u.email,
              tp.preferred_location, tp.max_budget, tp.preferred_category
       FROM users u
       JOIN tenant_profiles tp ON tp.user_id = u.id
       WHERE u.role = 'tenant'
         AND u.email IS NOT NULL
         AND tp.notify_new_listings IS NOT DISTINCT FROM true
       LIMIT 500`, []);
        for (const tenant of tenants.rows) {
            try {
                const conditions = [
                    `p.status = 'approved'`,
                    `p.availability_status = 'available'`,
                    `p.created_at > NOW() - INTERVAL '24 hours'`,
                ];
                const params = [];
                if (tenant.max_budget) {
                    params.push(tenant.max_budget);
                    conditions.push(`p.price <= $${params.length}`);
                }
                if (tenant.preferred_location) {
                    params.push(`%${tenant.preferred_location.toLowerCase()}%`);
                    conditions.push(`LOWER(p.city) LIKE $${params.length}`);
                }
                if (tenant.preferred_category) {
                    params.push(tenant.preferred_category);
                    conditions.push(`p.category = $${params.length}`);
                }
                const props = await query(`SELECT p.id, p.title, p.city AS location, p.price, p.image_url AS "imageUrl", p.category
           FROM properties p
           WHERE ${conditions.join(' AND ')}
           ORDER BY p.created_at DESC
           LIMIT 5`, params);
                if (props.rowCount === 0)
                    continue;
                const listings = props.rows.map((r) => ({
                    id: String(r.id),
                    title: String(r.title),
                    location: String(r.location),
                    price: Number(r.price),
                    imageUrl: r.imageUrl ? String(r.imageUrl) : undefined,
                    category: r.category ? String(r.category) : undefined,
                }));
                await sendDailyListingDigestEmail(tenant.email, tenant.name, listings);
                await queueUserPush(tenant.id, '🏠 New listings match your preferences!', `${listings.length} new propert${listings.length > 1 ? 'ies' : 'y'} just added matching your search.`, { type: 'daily_listing_alert', count: String(listings.length) });
            }
            catch (tenantErr) {
                console.error(`[cron] daily listing digest failed for userId=${tenant.id}:`, tenantErr);
            }
        }
        console.log(`[cron] daily listing alerts processed for ${tenants.rowCount} tenants`);
    }
    finally {
        await query(`SELECT pg_advisory_unlock(7001)`, []);
    }
}
// --- 8. Personalized promotions (2 PM EAT) -----------------------------------
async function sendPersonalizedPromotions() {
    const lockRes = await query(`SELECT pg_try_advisory_lock(7002) AS locked`, []);
    if (!lockRes.rows[0]?.locked)
        return;
    try {
        const tenants = await query(`SELECT DISTINCT u.id, u.name, u.email,
              COALESCE(array_agg(DISTINCT pv.property_id) FILTER (WHERE pv.property_id IS NOT NULL), '{}') AS viewed_ids,
              COALESCE(array_agg(DISTINCT sp.property_id) FILTER (WHERE sp.property_id IS NOT NULL), '{}') AS saved_ids
       FROM users u
       LEFT JOIN property_views pv ON pv.user_id = u.id AND pv.viewed_at > NOW() - INTERVAL '7 days'
       LEFT JOIN saved_properties sp ON sp.user_id = u.id AND sp.created_at > NOW() - INTERVAL '7 days'
       LEFT JOIN notification_log nl ON nl.user_id = u.id AND nl.type = 'personalized_promotion' AND nl.created_at > NOW() - INTERVAL '3 days'
       WHERE u.role = 'tenant'
         AND u.email IS NOT NULL
         AND nl.id IS NULL
         AND (pv.property_id IS NOT NULL OR sp.property_id IS NOT NULL)
       GROUP BY u.id, u.name, u.email
       LIMIT 200`, []);
        for (const tenant of tenants.rows) {
            try {
                const interactionIds = [...(tenant.viewed_ids || []), ...(tenant.saved_ids || [])].slice(0, 10);
                if (interactionIds.length === 0)
                    continue;
                const similar = await query(`SELECT DISTINCT p.id, p.title, p.city AS location, p.price, p.image_url AS "imageUrl", p.category
           FROM properties p
           JOIN properties ref ON ref.id = ANY($1::uuid[])
           WHERE p.status = 'approved'
             AND p.availability_status = 'available'
             AND p.id != ALL($1::uuid[])
             AND (p.city = ref.city OR p.category = ref.category)
           ORDER BY RANDOM()
           LIMIT 3`, [interactionIds]);
                if ((similar.rowCount ?? 0) === 0)
                    continue;
                const listings = similar.rows.map((r) => ({
                    id: String(r.id),
                    title: String(r.title),
                    location: String(r.location),
                    price: Number(r.price),
                    imageUrl: r.imageUrl ? String(r.imageUrl) : undefined,
                    category: r.category ? String(r.category) : undefined,
                }));
                await sendPersonalizedPromotionEmail(tenant.email, tenant.name, listings);
                await query(`INSERT INTO notification_log (user_id, type, created_at) VALUES ($1, 'personalized_promotion', NOW())
           ON CONFLICT DO NOTHING`, [tenant.id]);
                await queueUserPush(tenant.id, '✨ Properties curated for you', `We found ${listings.length} properties matching your interests.`, { type: 'personalized_promotion', count: String(listings.length) });
            }
            catch (err) {
                console.error(`[cron] personalized promotions failed for userId=${tenant.id}:`, err);
            }
        }
        console.log(`[cron] personalized promotions sent for ${tenants.rowCount} tenants`);
    }
    finally {
        await query(`SELECT pg_advisory_unlock(7002)`, []);
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
    // Property inquiry reminder — hourly, once per unanswered conversation
    cron.schedule('30 * * * *', sendLandlordInquiryReminders, { timezone: 'Africa/Nairobi' });
    // 5. Weekly landlord digest — every Monday 9:00 AM
    cron.schedule('0 9 * * 1', sendWeeklyPerformanceDigest, { timezone: 'Africa/Nairobi' });
    // 6. Host application reminders — evaluated hourly
    cron.schedule('0 * * * *', sendHostApplicationReminders, { timezone: 'Africa/Nairobi' });
    // Email verification follow-ups — evaluated hourly
    cron.schedule('0 * * * *', sendOtpVerificationReminders, { timezone: 'Africa/Nairobi' });
    // 7. Daily listing alerts — 10:00 AM EAT
    cron.schedule('0 10 * * *', sendDailyListingAlerts, { timezone: 'Africa/Nairobi' });
    // 8. Personalized promotions — 2:00 PM EAT
    cron.schedule('0 14 * * *', sendPersonalizedPromotions, { timezone: 'Africa/Nairobi' });
    console.log('[cron] All scheduled jobs registered (timezone: Africa/Nairobi)');
}
//# sourceMappingURL=cron.js.map