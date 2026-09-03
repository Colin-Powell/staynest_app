import { Job, Worker } from 'bullmq';
import { env } from '../config.js';
import { sendOtpEmail } from '../services/email.js';

const connection = { url: env.redisUrl };

export const emailWorker = new Worker(
  'email-delivery',
  async (job: Job<{ to: string; code: string }>) => {
    if (job.name !== 'otp-email') return;
    await sendOtpEmail(job.data.to, job.data.code);
  },
  { connection, concurrency: 3 },
);

emailWorker.on('completed', (job) => {
  console.info(`[EmailWorker] Job ${job.id} completed successfully.`);
});

emailWorker.on('failed', (job, error) => {
  console.error(`[EmailWorker] Job ${job?.id} failed:`, error);
});