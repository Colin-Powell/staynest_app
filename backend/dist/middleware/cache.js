import { cache } from '../services/cache.js';
export const routeCache = (ttlSeconds) => {
    return async (req, res, next) => {
        // Only cache GET requests
        if (req.method !== 'GET') {
            return next();
        }
        // Hash the URL to create a unique cache key
        // For simple endpoints without authentication data variations, URL + Query is sufficient.
        const key = `cache:${req.originalUrl || req.url}`;
        try {
            const cachedResponse = await cache.get(key);
            if (cachedResponse) {
                res.setHeader('X-Cache', 'HIT');
                return res.json(JSON.parse(cachedResponse));
            }
            // If not in cache, intercept res.json
            res.setHeader('X-Cache', 'MISS');
            const originalJson = res.json;
            res.json = (body) => {
                // Only cache successful responses
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    cache.set(key, JSON.stringify(body), ttlSeconds).catch(err => {
                        console.error('[Cache] Failed to set cache for', key, err);
                    });
                }
                return originalJson.call(res, body);
            };
            next();
        }
        catch (err) {
            console.error('[Cache] Error in middleware:', err);
            next(); // fallback to normal flow if cache fails
        }
    };
};
//# sourceMappingURL=cache.js.map