import fs from 'fs';
import path from 'path';
import { env } from '../config.js';
import { uploadToCloudinary as uploadToCloudinaryService, isCloudinaryConfigured as isConfigured } from './cloudinary.js';

const storageDirectory = path.resolve(process.cwd(), env.storagePath);

export function ensureStorageDirectory() {
  if (!fs.existsSync(storageDirectory)) {
    fs.mkdirSync(storageDirectory, { recursive: true });
  }
}

export function buildFileUrl(filename: string) {
  return `/uploads/${filename}`;
}

export function storageDestination() {
  ensureStorageDirectory();
  return storageDirectory;
}

// Re-export Cloudinary functions
export const uploadToCloudinary = uploadToCloudinaryService;
export const isCloudinaryConfigured = isConfigured;
