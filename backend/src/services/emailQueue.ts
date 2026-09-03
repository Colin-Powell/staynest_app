import { Queue } from 'bullmq';
import { env } from '../config.js';

const connection = { url: env.redisUrl };

export const emailQueue = new Queue('email-delivery', { connection });
