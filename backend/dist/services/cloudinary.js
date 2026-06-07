import { v2 as cloudinary } from 'cloudinary';
import { env } from '../config.js';
// Configure Cloudinary
cloudinary.config({
    cloud_name: env.cloudinaryCloudName,
    api_key: env.cloudinaryApiKey,
    api_secret: env.cloudinaryApiSecret,
});
/**
 * Upload file to Cloudinary.
 * public_id must NOT include the file extension — Cloudinary appends the
 * format automatically. Including it causes the asset to be stored with
 * the extension baked into the public_id, resulting in double-extension
 * URLs like "photo.jpg.jpg" that return 404.
 */
export async function uploadToCloudinary(fileBuffer, fileName, folder = 'staynest') {
    // Strip extension from fileName before using it as public_id
    const baseName = fileName
        .replace(/\.[^/.]+$/, '') // remove extension e.g. ".jpg"
        .replace(/[^a-zA-Z0-9-]/g, '-'); // sanitize to url-safe chars
    return new Promise((resolve, reject) => {
        const stream = cloudinary.uploader.upload_stream({
            folder,
            resource_type: 'auto',
            public_id: `${Date.now()}-${baseName}`,
        }, (error, result) => {
            if (error) {
                reject(error);
            }
            else {
                resolve({
                    url: result?.url || '',
                    secure_url: result?.secure_url || result?.url || '',
                    public_id: result?.public_id || '',
                });
            }
        });
        stream.end(fileBuffer);
    });
}
/**
 * Delete file from Cloudinary by public_id
 */
export async function deleteFromCloudinary(publicId) {
    return new Promise((resolve, reject) => {
        cloudinary.uploader.destroy(publicId, (error) => {
            if (error) {
                reject(error);
                return;
            }
            resolve();
        });
    });
}
/**
 * Check if Cloudinary is configured
 */
export function isCloudinaryConfigured() {
    return !!(env.cloudinaryCloudName && env.cloudinaryApiKey && env.cloudinaryApiSecret);
}
//# sourceMappingURL=cloudinary.js.map