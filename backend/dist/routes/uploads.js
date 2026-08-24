import { Router } from 'express';
import multer from 'multer';
import { requireAuth } from '../middleware/auth.js';
import { uploadToCloudinary, isCloudinaryConfigured, buildFileUrl, storageDestination, ensureStorageDirectory } from '../services/storage.js';
import { mediaQueue } from '../services/queue.js';
const router = Router();
ensureStorageDirectory();
// 1. Sync Storage (Memory for direct Cloudinary)
const syncStorage = isCloudinaryConfigured()
    ? multer.memoryStorage()
    : multer.diskStorage({
        destination: storageDestination(),
        filename: (_req, file, callback) => {
            const fileName = `${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9.-]/g, '-')}`;
            callback(null, fileName);
        },
    });
// 2. Async Storage (Always Disk to pass to BullMQ)
const asyncStorage = multer.diskStorage({
    destination: storageDestination(),
    filename: (_req, file, callback) => {
        const fileName = `async-${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9.-]/g, '-')}`;
        callback(null, fileName);
    },
});
function fileFilter(_req, file, callback) {
    // Allow all image and video formats
    const allowedExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.tiff', '.svg', '.heic', '.heif', '.mp4', '.mov', '.avi'];
    const fileExt = file.originalname.toLowerCase().substring(file.originalname.lastIndexOf('.'));
    if (allowedExtensions.includes(fileExt) || file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
        callback(null, true);
    }
    else {
        callback(new Error('Only image and video files are allowed.'));
    }
}
const uploadSync = multer({
    storage: syncStorage,
    fileFilter,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit for sync
});
const uploadAsync = multer({
    storage: asyncStorage,
    fileFilter,
    limits: { fileSize: 100 * 1024 * 1024 }, // 100MB limit for async media
});
// LEGACY SYNC ROUTE
router.post('/', requireAuth, uploadSync.single('file'), async (req, res, next) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded.' });
        }
        let url;
        let filename;
        if (isCloudinaryConfigured()) {
            const result = await uploadToCloudinary(req.file.buffer, req.file.originalname);
            url = result.secure_url;
            filename = result.public_id;
        }
        else {
            url = buildFileUrl(req.file.filename);
            filename = req.file.filename;
        }
        res.status(201).json({ data: { url, filename } });
    }
    catch (error) {
        next(error);
    }
});
// NEW ASYNC ROUTE
router.post('/async', requireAuth, uploadAsync.single('file'), async (req, res, next) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded.' });
        }
        // Queue the job to the worker
        const job = await mediaQueue.add('process-media', {
            filePath: req.file.path,
            originalName: req.file.originalname,
            mimeType: req.file.mimetype,
        });
        res.status(202).json({
            data: {
                jobId: job.id,
                status: 'queued'
            }
        });
    }
    catch (error) {
        next(error);
    }
});
// GET ASYNC JOB STATUS
router.get('/job/:id', requireAuth, async (req, res, next) => {
    try {
        const job = await mediaQueue.getJob(req.params.id);
        if (!job) {
            return res.status(404).json({ error: 'Job not found' });
        }
        const state = await job.getState();
        const isCompleted = state === 'completed';
        const isFailed = state === 'failed';
        res.json({
            data: {
                id: job.id,
                status: state,
                progress: job.progress,
                result: isCompleted ? job.returnvalue : null,
                error: isFailed ? job.failedReason : null,
            }
        });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=uploads.js.map