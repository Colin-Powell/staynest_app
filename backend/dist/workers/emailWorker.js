import { UnrecoverableError, Worker } from 'bullmq';
import { env } from '../config.js';
import { sendOtpEmail } from '../services/email.js';
const connection = { url: env.redisUrl };
export const emailWorker = new Worker('email-delivery', async (job) => {
    if (job.name !== 'otp-email')
        return;
    try {
        await sendOtpEmail(job.data.to, job.data.code);
    }
    catch (error) {
        const smtpError = error;
        if (smtpError.code === 'EAUTH' ||
            smtpError.responseCode === 535 ||
            (error instanceof Error && error.message.startsWith('SMTP is not configured.'))) {
            throw new UnrecoverableError('SMTP authentication failed. Check the email worker SMTP credentials.');
        }
        throw error;
    }
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