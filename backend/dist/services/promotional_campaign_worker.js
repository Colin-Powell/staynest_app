import { pool, query } from '../db.js';
import { sendPromotionalPushBatch } from './firebase.js';
import { isEligibleCampaignAvailability } from './promotional_campaign_policy.js';
const BATCH_SIZE = 500;
const TRANSIENT_ERROR_CODES = new Set([
    'messaging/server-unavailable',
    'messaging/internal-error',
    'messaging/unknown-error',
    'messaging/message-rate-exceeded',
    'messaging/device-message-rate-exceeded',
    'messaging/topics-message-rate-exceeded',
]);
export async function processPromotionalCampaign(campaignId) {
    const campaignResult = await query(`UPDATE promotional_push_campaigns c
     SET status = 'processing', sent_at = COALESCE(c.sent_at, now())
     FROM properties p
     WHERE c.id = $1 AND c.status IN ('queued', 'processing')
       AND p.id = c.property_id AND p.status = 'approved'
       AND lower(coalesce(p.availability_status, '')) IN ('available', 'pending_booking')
    RETURNING c.id, c.property_id, c.title, c.body, c.image_url, c.audience,
        p.availability_status, p.city, p.category`, [campaignId]);
    const campaign = campaignResult.rows[0];
    if (!campaign) {
        const pending = await query(`UPDATE promotional_push_deliveries
       SET status = 'failed', error_category = 'property_ineligible',
           error_detail = 'The selected property is no longer available.', updated_at = now()
       WHERE campaign_id = $1 AND status IN ('pending', 'sending') RETURNING id`, [campaignId]);
        if (pending.rows.length > 0) {
            await query(`UPDATE promotional_push_campaigns SET status = 'failed', failed_count = $2,
           failure_summary = 'The selected property is no longer eligible.', completed_at = now()
         WHERE id = $1 AND status IN ('queued', 'processing')`, [campaignId, pending.rows.length]);
        }
        return;
    }
    if (!isEligibleCampaignAvailability(campaign.availability_status))
        return;
    while (true) {
        const client = await pool.connect();
        let recipients = [];
        try {
            await client.query('BEGIN');
            const recipientResult = await client.query(`SELECT d.id AS delivery_id, d.user_id, u.fcm_token
         FROM promotional_push_deliveries d
         JOIN users u ON u.id = d.user_id
         WHERE d.campaign_id = $1
           AND (d.status = 'pending' OR (d.status = 'sending' AND d.last_attempt_at < now() - INTERVAL '30 minutes'))
           AND u.fcm_token IS NOT NULL AND btrim(u.fcm_token) <> ''
         ORDER BY d.created_at
         LIMIT $2
         FOR UPDATE OF d SKIP LOCKED`, [campaignId, BATCH_SIZE]);
            recipients = recipientResult.rows;
            if (recipients.length > 0) {
                await client.query(`UPDATE promotional_push_deliveries
           SET status = 'sending', attempt_count = attempt_count + 1,
               last_attempt_at = now(), updated_at = now()
           WHERE id = ANY($1::uuid[])`, [recipients.map((recipient) => recipient.delivery_id)]);
            }
            await client.query('COMMIT');
        }
        catch (error) {
            await client.query('ROLLBACK').catch(() => undefined);
            throw error;
        }
        finally {
            client.release();
        }
        if (recipients.length === 0)
            break;
        let results;
        try {
            results = await sendPromotionalPushBatch(recipients.map((recipient) => ({
                token: recipient.fcm_token,
                title: campaign.title,
                body: campaign.body,
                imageUrl: campaign.image_url,
                campaignId,
                propertyId: campaign.property_id,
            })));
        }
        catch (error) {
            await query(`UPDATE promotional_push_deliveries
         SET error_category = 'batch_transport_error',
             error_detail = 'The FCM batch could not be confirmed.', updated_at = now()
         WHERE id = ANY($1::uuid[]) AND status = 'sending'`, [recipients.map((recipient) => recipient.delivery_id)]);
            throw error;
        }
        let hasTransientFailure = false;
        for (let index = 0; index < recipients.length; index += 1) {
            const recipient = recipients[index];
            const result = results[index];
            const errorCode = result.errorCode ?? null;
            const invalidToken = errorCode === 'messaging/registration-token-not-registered' ||
                errorCode === 'messaging/invalid-registration-token';
            const transient = errorCode !== null && TRANSIENT_ERROR_CODES.has(errorCode);
            const status = result.success ? 'submitted' : transient ? 'pending' : 'failed';
            if (transient)
                hasTransientFailure = true;
            await query(`UPDATE promotional_push_deliveries
         SET status = $1, fcm_message_id = $2,
           error_category = $3, error_detail = $4, updated_at = now()
         WHERE id = $5`, [status, result.messageId ?? null, errorCode, errorCode ? 'FCM rejected this message.' : null, recipient.delivery_id]);
            if (invalidToken) {
                await query('UPDATE users SET fcm_token = NULL WHERE id = $1 AND fcm_token = $2', [recipient.user_id, recipient.fcm_token]);
            }
        }
        await query(`UPDATE promotional_push_campaigns c
       SET submitted_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'submitted'),
           failed_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'failed'),
           skipped_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'skipped')
       WHERE c.id = $1 AND c.status = 'processing'`, [campaignId]);
        if (hasTransientFailure)
            throw new Error('Promotional campaign has transient FCM failures.');
    }
    await query(`UPDATE promotional_push_deliveries d
     SET status = 'skipped', updated_at = now()
     WHERE d.campaign_id = $1 AND d.status = 'pending'
       AND NOT EXISTS (
         SELECT 1 FROM users u
         JOIN promotional_push_campaigns c ON c.id = d.campaign_id
         WHERE u.id = d.user_id
           AND u.fcm_token IS NOT NULL AND btrim(u.fcm_token) <> ''
       )`, [campaignId]);
    await query(`UPDATE promotional_push_campaigns c
     SET submitted_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'submitted'),
         failed_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'failed'),
       skipped_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'skipped'),
         status = CASE WHEN EXISTS (
           SELECT 1 FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'failed'
         ) THEN 'completed_with_errors' ELSE 'completed' END,
         completed_at = now()
     WHERE c.id = $1
       AND NOT EXISTS (
       SELECT 1 FROM promotional_push_deliveries d
       WHERE d.campaign_id = c.id AND d.status IN ('pending', 'sending')
       )`, [campaignId]);
}
//# sourceMappingURL=promotional_campaign_worker.js.map