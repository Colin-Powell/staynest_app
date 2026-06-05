import { Router } from 'express';
import multer from 'multer';
import { requireAuth } from '../middleware/auth.js';
import { uploadToCloudinary, isCloudinaryConfigured, buildFileUrl, storageDestination } from '../services/storage.js';
const router = Router();
// Use memory storage for Cloudinary, disk storage fallback
const storage = isCloudinaryConfigured()
    ? multer.memoryStorage()
    : multer.diskStorage({
        destination: storageDestination(),
        filename: (req, file, callback) => {
            const fileName = `${Date.now()}-${file.originalname.replace(/[^a-zA-Z0-9.-]/g, '-')}`;
            callback(null, fileName);
        },
    });
function fileFilter(req, file, callback) {
    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
        callback(null, true);
    }
    else {
        callback(new Error('Only PNG, JPEG, JPG and WEBP images are allowed.'));
    }
}
const upload = multer({
    storage,
    fileFilter,
    limits: {
        fileSize: 10 * 1024 * 1024,
    },
});
router.post('/', requireAuth, upload.single('file'), async (req, res, next) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded.' });
        }
        let url;
        let filename;
        if (isCloudinaryConfigured()) {
            // Upload to Cloudinary
            const result = await uploadToCloudinary(req.file.buffer, req.file.originalname);
            url = result.secure_url;
            filename = result.public_id;
        }
        else {
            // Fallback to disk storage
            url = buildFileUrl(req.file.filename);
            filename = req.file.filename;
        }
        res.status(201).json({ data: { url, filename } });
    }
    catch (error) {
        next(error);
    }
});
export default router;
//# sourceMappingURL=uploads.js.map