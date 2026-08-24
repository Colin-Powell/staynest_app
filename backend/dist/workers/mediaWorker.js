import { Worker } from 'bullmq';
import fs from 'fs';
import sharp from 'sharp';
import ffmpeg from 'fluent-ffmpeg';
import { uploadToCloudinary } from '../services/storage.js';
import dotenv from 'dotenv';
dotenv.config();
const connection = {
    url: process.env.REDIS_URL || 'redis://127.0.0.1:6379',
};
export const mediaWorker = new Worker('media-processing', async (job) => {
    const { filePath, originalName, mimeType } = job.data;
    let processedBuffer;
    try {
        let isImage = mimeType.startsWith('image/');
        let isVideo = mimeType.startsWith('video/');
        // Fallback for Flutter application/octet-stream uploads
        if (!isImage && !isVideo) {
            const lowerName = originalName.toLowerCase();
            if (lowerName.match(/\.(jpg|jpeg|png|webp|gif|bmp)$/))
                isImage = true;
            if (lowerName.match(/\.(mp4|mov|avi|mkv|webm)$/))
                isVideo = true;
        }
        if (isImage) {
            // Compress image with Sharp
            processedBuffer = await sharp(filePath)
                .resize(1920, 1080, { fit: 'inside', withoutEnlargement: true })
                .webp({ quality: 80 })
                .toBuffer();
            const result = await uploadToCloudinary(processedBuffer, `${originalName}.webp`);
            return result;
        }
        else if (isVideo) {
            // Compress video with FFmpeg
            const outputPath = `${filePath}_processed.mp4`;
            await new Promise((resolve, reject) => {
                ffmpeg(filePath)
                    .size('?x720')
                    .fps(30)
                    .videoCodec('libx264')
                    .on('end', resolve)
                    .on('error', reject)
                    .save(outputPath);
            });
            const videoBuffer = fs.readFileSync(outputPath);
            const result = await uploadToCloudinary(videoBuffer, `${originalName}.mp4`);
            // cleanup processed video
            fs.unlinkSync(outputPath);
            return result;
        }
        throw new Error(`Unsupported media type: ${mimeType}`);
    }
    finally {
        // Always cleanup original local file
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
    }
}, { connection, concurrency: 2 } // Process up to 2 uploads concurrently
);
mediaWorker.on('completed', (job) => {
    console.log(`[MediaWorker] Job ${job.id} completed successfully.`);
});
mediaWorker.on('failed', (job, err) => {
    console.error(`[MediaWorker] Job ${job?.id} failed with error:`, err);
});
//# sourceMappingURL=mediaWorker.js.map