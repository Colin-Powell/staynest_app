import { Queue } from 'bullmq';
import dotenv from 'dotenv';
dotenv.config();

const connection = {
  url: process.env.REDIS_URL || 'redis://127.0.0.1:6379',
};

export const mediaQueue = new Queue('media-processing', { connection });
