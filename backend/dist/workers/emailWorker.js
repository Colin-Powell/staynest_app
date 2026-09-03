import { Worker } from 'bullmq';
import { env } from '../config.js';
import { sendOtpEmail } from '../services/email.js';
const connection = { url: env.redisUrl };
export const emailWorker = new Worker('email-delivery', async (job) => {
    if (job.name !== 'otp-email')
        return;
    await sendOtpEmail(job.data.to, job.data.code);
}, { connection, concurrency: 3 });
emailWorker.on('ready', () => {
    console.info('[EmailWorker] Connected to Redis and ready for jobs.');
});
emailWorker.on('error', (error) => {
    console.error('[EmailWorker] Worker error:', error);
});
emailWorker.on('completed', (job) => {
    console.info(`[EmailWorker] Job ${job.id} completed successfully.`);
});
emailWorker.on('failed', (job, error) => {
    console.error(`[EmailWorker] Job ${job?.id} failed:`, error);
});
//# sourceMappingURL=emailWorker.js.map