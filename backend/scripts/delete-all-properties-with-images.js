import { v2 as cloudinary } from 'cloudinary';
import dotenv from 'dotenv';
import path from 'path';
import { Pool } from 'pg';

// Script to delete ALL property rows and also delete their associated images from Cloudinary.
// Usage: node backend/scripts/delete-all-properties-with-images.js

dotenv.config({ path: path.resolve(process.cwd(), 'backend', '.env') });

function parseCloudinaryUrl(url) {
  try {
    const match = url.match(/cloudinary:\/\/([^:]+):([^@]+)@(.+)/);
    if (match) {
      return {
        cloudinaryApiKey: match[1],
        cloudinaryApiSecret: match[2],
        cloudinaryCloudName: match[3],
      };
    }
  } catch (_) {}
  return { cloudinaryApiKey: '', cloudinaryApiSecret: '', cloudinaryCloudName: '' };
}

function isCloudinaryConfigured(cloudinaryCfg) {
  return !!(
    cloudinaryCfg.cloudinaryCloudName &&
    cloudinaryCfg.cloudinaryApiKey &&
    cloudinaryCfg.cloudinaryApiSecret
  );
}

function extractPublicIdFromCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return null;
  const uploadMarker = '/upload/';
  const idx = url.indexOf(uploadMarker);
  if (idx === -1) return null;

  const after = url.slice(idx + uploadMarker.length);
  let s = after.replace(/^v\d+\//, '');
  s = s.replace(/\.[a-zA-Z0-9]+$/, '');
  return s || null;
}

async function main() {
  const databaseUrl = process.env.DATABASE_URL || 'postgresql://postgres:postgres@db:5432/staynest';

  const cloudinaryCfg = parseCloudinaryUrl(process.env.CLOUDINARY_URL || '');

  const pool = new Pool({ connectionString: databaseUrl });

  if (isCloudinaryConfigured(cloudinaryCfg)) {
    cloudinary.config({
      cloud_name: cloudinaryCfg.cloudinaryCloudName,
      api_key: cloudinaryCfg.cloudinaryApiKey,
      api_secret: cloudinaryCfg.cloudinaryApiSecret,
    });
  } else {
    console.warn('Cloudinary is not configured (CLOUDINARY_URL missing). DB rows will still be deleted.');
  }

  const query = (text, params) => pool.query(text, params);

  console.log('Starting delete-all-properties-with-images...');

  const propsRes = await query(
    `SELECT id, image_url, images
     FROM properties
     ORDER BY created_at DESC`
  );

  const publicIdsToDelete = new Set();

  for (const p of propsRes.rows || []) {
    const candidates = [];
    if (p.image_url) candidates.push(p.image_url);

    if (Array.isArray(p.images)) {
      for (const item of p.images) {
        if (typeof item === 'string') candidates.push(item);
      }
    }

    for (const url of candidates) {
      const publicId = extractPublicIdFromCloudinaryUrl(url);
      if (publicId) publicIdsToDelete.add(publicId);
    }
  }

  console.log(`Found ${publicIdsToDelete.size} Cloudinary image public_id(s) to delete.`);

  const beforeCount = await query(`SELECT COUNT(*)::int AS count FROM properties`);
  console.log(`Properties before delete: ${(beforeCount.rows?.[0]?.count ?? 0).toString()}`);

  await query('BEGIN');
  try {
    await query('DELETE FROM properties');
    await query('COMMIT');
  } catch (e) {
    await query('ROLLBACK');
    throw e;
  }

  const afterCount = await query(`SELECT COUNT(*)::int AS count FROM properties`);
  console.log(`Properties after delete: ${(afterCount.rows?.[0]?.count ?? 0).toString()}`);

  if (publicIdsToDelete.size > 0 && isCloudinaryConfigured(cloudinaryCfg)) {
    console.log('Deleting images from Cloudinary...');

    for (const publicId of publicIdsToDelete) {
      try {
        await new Promise((resolve, reject) => {
          cloudinary.uploader.destroy(publicId, { invalidate: true }, (err) => {
            if (err) return reject(err);
            resolve();
          });
        });
        console.log(`Deleted: ${publicId}`);
      } catch (err) {
        console.warn(`Failed to delete ${publicId}:`, err?.message || err);
      }
    }
  }

  console.log('Done.');
  await pool.end();
}

main()
  .then(() => process.exit(0))
  .catch(async (err) => {
    console.error('delete-all-properties-with-images failed:', err);
    process.exit(1);
  });

