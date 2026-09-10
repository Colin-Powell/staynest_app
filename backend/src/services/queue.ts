import { Queue, Worker, QueueEvents } from 'bullmq';
import { env } from '../config.js';
import { sendPushToUser, sendPushToTopic } from './firebase.js';

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
  }
}, { 
  connection,
  concurrency: 5
});

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
