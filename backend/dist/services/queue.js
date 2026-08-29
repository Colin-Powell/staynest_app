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
queueEvents.on('completed', ({ jobId }) => {
    console.log(`[Queue] Notification job ${jobId} completed successfully.`);
});
queueEvents.on('failed', ({ jobId, failedReason }) => {
    console.error(`[Queue] Notification job ${jobId} failed:`, failedReason);
});
export const notificationWorker = new Worker('notifications', async (job) => {
    const { type, payload } = job.data;
    if (type === 'push_user') {
        const { userId, title, body, data } = payload;
        const success = await sendPushToUser(userId, title, body, data);
        if (!success) {
            throw new Error(`Failed to send push to user ${userId}`);
        }
    }
    else if (type === 'push_topic') {
        const { topic, title, body, data } = payload;
        const success = await sendPushToTopic(topic, title, body, data);
        if (!success) {
            throw new Error(`Failed to send push to topic ${topic}`);
        }
    }
}, {
    connection,
    concurrency: 5
});
export async function queueUserPush(userId, title, body, data) {
    await notificationQueue.add('push_notification', {
        type: 'push_user',
        payload: { userId, title, body, data }
    }, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: true,
    });
}
export async function queueTopicPush(topic, title, body, data) {
    await notificationQueue.add('push_notification', {
        type: 'push_topic',
        payload: { topic, title, body, data }
    }, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 },
        removeOnComplete: true,
    });
}
//# sourceMappingURL=queue.js.map