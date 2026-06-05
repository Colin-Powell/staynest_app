import { v2 as cloudinary } from 'cloudinary';
import { env } from '../config.js';

// Configure Cloudinary
cloudinary.config({
  cloud_name: env.cloudinaryCloudName,
  api_key: env.cloudinaryApiKey,
  api_secret: env.cloudinaryApiSecret,
});

export interface UploadResult {
  url: string;
  public_id: string;
  secure_url: string;
}

/**
 * Upload file to Cloudinary using unsigned upload
 * Returns the secure URL for the uploaded image
 */
export async function uploadToCloudinary(
  fileBuffer: Buffer,
  fileName: string,
  folder: string = 'staynest'
): Promise<UploadResult> {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder: folder,
        resource_type: 'auto',
        public_id: `${Date.now()}-${fileName.replace(/[^a-zA-Z0-9.-]/g, '-')}`,
      },
      (error, result) => {
        if (error) {
          reject(error);
        } else {
          resolve({
            url: result?.url || '',
            secure_url: result?.secure_url || result?.url || '',
            public_id: result?.public_id || '',
          });
        }
      }
    );

    stream.end(fileBuffer);
  });
}

/**
 * Delete file from Cloudinary by public_id
 */
export async function deleteFromCloudinary(publicId: string): Promise<void> {
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
export function isCloudinaryConfigured(): boolean {
  return !!(env.cloudinaryCloudName && env.cloudinaryApiKey && env.cloudinaryApiSecret);
}
