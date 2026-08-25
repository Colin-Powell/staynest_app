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
        // If file doesn't exist anymore (e.g. on a retry after it was deleted), we can't process it.
        if (!fs.existsSync(filePath)) {
            throw new Error(`Input file is missing (possibly deleted during a previous failed attempt): ${filePath}`);
        }
        let result;
        if (isImage) {
            // Compress image with Sharp
            processedBuffer = await sharp(filePath)
                .resize(1920, 1080, { fit: 'inside', withoutEnlargement: true })
                .webp({ quality: 80 })
                .toBuffer();
            result = await uploadToCloudinary(processedBuffer, `${originalName}.webp`);
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
            result = await uploadToCloudinary(videoBuffer, `${originalName}.mp4`);
            // cleanup processed video
            if (fs.existsSync(outputPath))
                fs.unlinkSync(outputPath);
        }
        else {
            throw new Error(`Unsupported media type: ${mimeType}`);
        }
        // Success! Cleanup original local file
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }
        return result;
    }
    catch (error) {
        // If we failed, check if we will retry. If we have exhausted retries, cleanup.
        // By default, if we don't know the retry strategy, it's safer to leave the file for retries
        // and maybe have a cron job clean up old files in the uploads folder.
        // For now, let's just log it.
        console.error(`Job ${job.id} failed on attempt ${job.attemptsMade + 1}. Error: ${error.message}`);
        // If the error was NOT "file missing", and we are abandoning the job, we should clean up.
        // However, to be safe for retries, we won't delete the file here.
        throw error;
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