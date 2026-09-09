import express from 'express';
import cors from 'cors';
import { apiRateLimiter } from './middleware/rateLimiter.js';
import { requestLogger } from './middleware/logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import authRouter from './routes/auth.js'; // Assuming requireAuth is imported here or available globally
import propertiesRouter from './routes/properties.js';
import promotionsRouter from './routes/promotions.js';
import usersRouter from './routes/users.js';
import uploadsRouter from './routes/uploads.js';
import verificationsRouter from './routes/verifications.js';
import notificationsRouter from './routes/notifications.js';
import emailRouter from './routes/email.js';
import googleAuthRouter from './routes/google_auth.js';
import tenantProfilesRouter from './routes/tenant_profiles.js';
import privacyRouter from './routes/privacy.js';
import messagesRouter from './routes/messages.js';
import bookingsRouter from './routes/bookings.js';
import analyticsRouter from './routes/analytics.js';
import adminRouter from './routes/admin.js';
import draftsRouter from './routes/drafts.js';
import versionRouter from './routes/version.js';
import paymentsRouter from './routes/payments.js';
import landlordPaymentMethodsRouter from './routes/landlord_payment_methods.js';
import path from 'path';
import { fileURLToPath } from 'url';
import { requireAuth } from './middleware/auth.js'; // Explicitly import requireAuth
const app = express();
// Trust the first proxy (e.g., Render load balancer) for express-rate-limit
app.set('trust proxy', 1);
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
const __dirname = path.dirname(fileURLToPath(import.meta.url));
app.use(express.static(path.join(__dirname, '../public')));
app.use(cors()); // Totally open CORS for all origins, headers, and methods
app.use(requestLogger);
app.use(apiRateLimiter);
app.use('/api/auth', authRouter);
app.use('/api/properties', propertiesRouter);
app.use('/api/promotions', promotionsRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api/landlord', landlordPaymentMethodsRouter);
app.use('/api/drafts', draftsRouter);
app.use('/api/version', versionRouter);
app.use('/api/users', usersRouter);
app.use('/api/uploads', uploadsRouter);
app.use('/api/verifications', verificationsRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/email', emailRouter);
app.use('/api/auth/google', googleAuthRouter);
// Backward-compatible alias for older clients
// (e.g. Flutter listing flow uses /api/landlord/verification)
import { createVerificationHandler } from './routes/verifications.js';
app.post('/api/landlord/verification', requireAuth, createVerificationHandler);
app.use('/api/tenant_profiles', tenantProfilesRouter);
app.use('/api/privacy', privacyRouter);
app.use('/api/messages', messagesRouter);
app.use('/api/bookings', bookingsRouter);
app.use('/api/analytics', analyticsRouter);
app.use('/api/admin', adminRouter);
app.get('/api/health', (_req, res) => {
    res.json({ status: 'ok', environment: process.env.NODE_ENV || 'development' });
});
app.use(errorHandler);
export default app;
//# sourceMappingURL=app.js.map