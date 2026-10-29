import { Queue, Worker, QueueEvents } from 'bullmq';
import { env } from '../config.js';
import { sendPushToUser, sendPushToTopic } from './firebase.js';
import { query } from '../db.js';
import { processPromotionalCampaign } from './promotional_campaign_worker.js';

const connection = {
  url: env.redisUrl || 'redis://127.0.0.1:6379',
};

// --- EXISTING MEDIA QUEUE ---
export const mediaQueue = new Queue('media-processing', { connection });

// --- NEW NOTIFICATION QUEUE ---
export const notificationQueue = new Queue('notifications', { connection });

const queueEvents = new QueueEvents('notifications', { connection });
queueEvents.on('error', (error) => {
  console.error('[Queue] Notification QueueEvents error:', error);
});
queueEvents.on('completed', ({ jobId }) => {
  console.log(`[Queue] Notification job ${jobId} completed successfully.`);
});
queueEvents.on('failed', ({ jobId, failedReason }) => {
  console.error(`[Queue] Notification job ${jobId} failed:`, failedReason);
});

export const notificationWorker = new Worker('notifications', async (job) => {
  const { type, payload } = job.data;
  console.log(`[Queue] processing job=${job.id} type=${type} target=${payload?.userId ?? payload?.topic ?? '-'}`);

  if (type === 'push_user') {
    const { userId, title, body, data } = payload;
    const success = await sendPushToUser(userId, title, body, data);
    if (!success) {
      throw new Error(`Failed to send push to user ${userId}`);
    }
    console.log(`[Queue] push user delivered job=${job.id} userId=${userId}`);
  } else if (type === 'push_topic') {
    const { topic, title, body, data } = payload;
    const success = await sendPushToTopic(topic, title, body, data);
    if (!success) {
      throw new Error(`Failed to send push to topic ${topic}`);
    }
    console.log(`[Queue] push topic delivered job=${job.id} topic=${topic}`);
  } else if (type === 'push_campaign') {
    await processPromotionalCampaign(payload.campaignId);
  }
}, { 
  connection,
  concurrency: 5
});

notificationWorker.on('failed', (job, error) => {
  if (!job || job.data?.type !== 'push_campaign') return;
  console.error(`[PushCampaign] job failed id=${job.data.payload?.campaignId}:`, error.message);
  if (job.attemptsMade < (job.opts.attempts ?? 1)) return;
  const campaignId = job.data.payload?.campaignId;
  if (typeof campaignId !== 'string') return;
  void query(
    `UPDATE promotional_push_deliveries
     SET status = 'failed', attempt_count = attempt_count + 1,
         last_attempt_at = now(), error_category = 'retry_exhausted',
         error_detail = 'Temporary delivery retries were exhausted.', updated_at = now()
    WHERE campaign_id = $1 AND status IN ('pending', 'sending')`,
    [campaignId],
  ).then(() => query(
    `UPDATE promotional_push_campaigns c
     SET failed_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'failed'),
         submitted_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'submitted'),
       skipped_count = (SELECT count(*)::int FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'skipped'),
         status = CASE WHEN EXISTS (
           SELECT 1 FROM promotional_push_deliveries d WHERE d.campaign_id = c.id AND d.status = 'submitted'
         ) THEN 'completed_with_errors' ELSE 'failed' END,
         failure_summary = 'Some messages could not be submitted after bounded retries.',
         completed_at = now()
     WHERE c.id = $1 AND c.status = 'processing'`,
    [campaignId],
  )).catch((updateError) => {
    console.error(`[PushCampaign] failed to persist terminal state id=${campaignId}:`, updateError);
  });
});

export async function queuePromotionalCampaign(campaignId: string) {
  const jobId = `promotional-campaign-${campaignId}`;
  const existing = await notificationQueue.getJob(jobId);
  if (existing) {
    const state = await existing.getState();
    if (['waiting', 'active', 'delayed', 'waiting-children', 'prioritized'].includes(state)) {
      return existing;
    }
    await existing.remove();
  }
  return notificationQueue.add('push_notification', {
    type: 'push_campaign',
    payload: { campaignId },
  }, {
    jobId,
    attempts: 5,
    backoff: { type: 'exponential', delay: 5000 },
  });
}

async function recoverQueuedPromotionalCampaigns() {
  try {
    await query(
      `UPDATE promotional_push_deliveries d
       SET status = 'pending', updated_at = now()
       FROM promotional_push_campaigns c
       WHERE d.campaign_id = c.id AND c.status = 'processing'
         AND d.status = 'sending'
         AND d.last_attempt_at < now() - INTERVAL '30 minutes'`,
    );
    const result = await query(
      `SELECT c.id FROM promotional_push_campaigns c
       WHERE c.status = 'queued'
          OR (c.status = 'processing' AND EXISTS (
            SELECT 1 FROM promotional_push_deliveries d
            WHERE d.campaign_id = c.id AND d.status = 'pending'
          ))
       ORDER BY c.created_at LIMIT 100`,
    );
    for (const campaign of result.rows as Array<{ id: string }>) {
      await queuePromotionalCampaign(campaign.id);
    }
  } catch (error) {
    console.error('[PushCampaign] queued campaign recovery will retry:', error);
  }
}

const campaignRecoveryTimer = setInterval(() => {
  void recoverQueuedPromotionalCampaigns();
}, 15000);
campaignRecoveryTimer.unref();
void recoverQueuedPromotionalCampaigns();

export async function queueUserPush(userId: string, title: string, body: string, data?: Record<string, string>) {
  console.log(`[Queue] enqueue push userId=${userId} title=${JSON.stringify(title)}`);
  try {
    const job = await notificationQueue.add('push_notification', {
      type: 'push_user',
      payload: { userId, title, body, data }
    }, {
      attempts: 3,
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: true,
    });
    console.log(`[Queue] enqueued job=${job.id} userId=${userId}`);
  } catch (error) {
    // Critical user notifications must still work during a Redis outage.
    console.error(`[Queue] enqueue failed; sending directly userId=${userId}:`, error);
    const delivered = await sendPushToUser(userId, title, body, data);
    if (!delivered) throw error;
  }
}

export async function queueTopicPush(topic: string, title: string, body: string, data?: Record<string, string>) {
  await notificationQueue.add('push_notification', {
    type: 'push_topic',
    payload: { topic, title, body, data }
  }, {
    attempts: 3,
    backoff: { type: 'exponential', delay: 2000 },
    removeOnComplete: true,
  });
}
