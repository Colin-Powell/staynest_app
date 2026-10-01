import dotenv from 'dotenv';
import path from 'path';
dotenv.config({ path: path.resolve(process.cwd(), '.env') });
const parseIntOrDefault = (value, fallback) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};
// Parse Cloudinary URL format: cloudinary://api_key:api_secret@cloud_name
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
    }
    catch (_) {
        // Ignore parse errors
    }
    return {
        cloudinaryApiKey: '',
        cloudinaryApiSecret: '',
        cloudinaryCloudName: '',
    };
}
const cloudinaryConfig = parseCloudinaryUrl(process.env.CLOUDINARY_URL || '');
export const env = {
    port: parseIntOrDefault(process.env.PORT, 8080),
    get jwtSecret() {
        const secret = process.env.JWT_SECRET?.trim();
        if (!secret) {
            throw new Error('FATAL ERROR: JWT_SECRET environment variable is not defined.');
        }
        return secret;
    },
    databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@db:5432/staynest',
    corsOrigin: process.env.CORS_ORIGIN || '*', // Changed to * to support random local Flutter ports
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
    emailFrom: process.env.EMAIL_FROM || process.env.SMTP_USER || '',
    googleClientId: process.env.GOOGLE_CLIENT_ID || '193200636263-vsbg83ntukhk0vcj8fkgtvfll3b4chk6.apps.googleusercontent.com',
    firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || '',
    appLatestVersion: process.env.APP_LATEST_VERSION || '1.0.0',
    appUpdateUrl: process.env.APP_UPDATE_URL || 'https://staynest.top/update.html',
    forceUpdate: process.env.FORCE_UPDATE === 'true',
    redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
    // M-Pesa Configuration
    mpesaConsumerKey: process.env.MPESA_CONSUMER_KEY || '',
    mpesaConsumerSecret: process.env.MPESA_CONSUMER_SECRET || '',
    mpesaBusinessShortCode: process.env.MPESA_BUSINESS_SHORT_CODE || '174379',
    mpesaPassKey: process.env.MPESA_PASS_KEY || 'bfb279f9aa9bdbcf158e97dd71a467cd',
    mpesaInitiatorName: process.env.MPESA_INITIATOR_NAME || '',
    mpesaSecurityCredential: process.env.MPESA_SECURITY_CREDENTIAL || '',
    mpesaB2cShortCode: process.env.MPESA_B2C_SHORT_CODE || process.env.MPESA_BUSINESS_SHORT_CODE || '',
    apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
};
//# sourceMappingURL=config.js.map