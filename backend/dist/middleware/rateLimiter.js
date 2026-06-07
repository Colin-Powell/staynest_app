import rateLimit from 'express-rate-limit';
import { env } from '../config.js';
export const apiRateLimiter = rateLimit({
    windowMs: env.rateLimitWindowMs,
    max: env.rateLimitMax,
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        error: 'Too many requests, please try again later.',
    },
});
//# sourceMappingURL=rateLimiter.js.map