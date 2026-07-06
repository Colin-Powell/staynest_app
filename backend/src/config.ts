import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(process.cwd(), '.env') });

const parseIntOrDefault = (value: string | undefined, fallback: number) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

// Parse Cloudinary URL format: cloudinary://api_key:api_secret@cloud_name
function parseCloudinaryUrl(url: string) {
  try {
    const match = url.match(/cloudinary:\/\/([^:]+):([^@]+)@(.+)/);
    if (match) {
      return {
        cloudinaryApiKey: match[1],
        cloudinaryApiSecret: match[2],
        cloudinaryCloudName: match[3],
      };
    }
  } catch (_) {
    // Ignore parse errors
  }
  return {
    cloudinaryApiKey: '',
    cloudinaryApiSecret: '',
    cloudinaryCloudName: '',
  };
}

const cloudinaryConfig = parseCloudinaryUrl(
  process.env.CLOUDINARY_URL || ''
);

export const env = {
  port: parseIntOrDefault(process.env.PORT, 8080),
  jwtSecret: process.env.JWT_SECRET?.trim() || 'replace-with-strong-secret',
  databaseUrl:
    process.env.DATABASE_URL || 'postgresql://postgres:postgres@db:5432/staynest',
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:8080',
  storagePath: process.env.STORAGE_PATH || 'uploads',
  rateLimitWindowMs: parseIntOrDefault(process.env.RATE_LIMIT_WINDOW_MS, 15 * 60 * 1000),
  rateLimitMax: parseIntOrDefault(process.env.RATE_LIMIT_MAX, 120),
  cloudinaryCloudName: cloudinaryConfig.cloudinaryCloudName,
  cloudinaryApiKey: cloudinaryConfig.cloudinaryApiKey,
  cloudinaryApiSecret: cloudinaryConfig.cloudinaryApiSecret,
  skipAdminVerification: process.env.SKIP_ADMIN_VERIFICATION === 'true',
  // SMTP / Email
  smtpHost: process.env.SMTP_HOST || '',
  smtpPort: parseIntOrDefault(process.env.SMTP_PORT, 587),
  smtpUser: process.env.SMTP_USER || '',
  smtpPass: process.env.SMTP_PASS || '',
  emailFrom: process.env.EMAIL_FROM || 'StayNest <no-reply@staynest.app>',
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
};
