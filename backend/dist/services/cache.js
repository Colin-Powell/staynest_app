import { createClient } from 'redis';
import { LRUCache } from 'lru-cache';
import dotenv from 'dotenv';
dotenv.config();
// 1. Redis Cache Implementation
class RedisCache {
    constructor(url) {
        this.isConnected = false;
        this.client = createClient({ url });
        this.client.on('error', (err) => {
            console.error('[Redis] Cache Error:', err);
            this.isConnected = false;
        });
        this.client.on('connect', () => {
            console.log('[Redis] Connected to Cache');
            this.isConnected = true;
        });
        this.client.connect().catch(console.error);
    }
    async get(key) {
        if (!this.isConnected)
            return null;
        try {
            return await this.client.get(key);
        }
        catch {
            return null;
        }
    }
    async set(key, value, ttlSeconds) {
        if (!this.isConnected)
            return;
        try {
            await this.client.set(key, value, { EX: ttlSeconds });
        }
        catch {
            // ignore
        }
    }
    async del(pattern) {
        if (!this.isConnected)
            return;
        try {
            const keys = await this.client.keys(pattern);
            if (keys.length > 0) {
                await this.client.del(keys);
            }
        }
        catch {
            // ignore
        }
    }
}
// 2. Local Memory Fallback Cache
class MemoryCache {
    constructor() {
        this.cache = new LRUCache({
            max: 500, // max items
            ttl: 1000 * 60 * 60, // default 1 hour
        });
        console.log('[MemoryCache] Initialized In-Memory LRU Cache Fallback');
    }
    async get(key) {
        return this.cache.get(key) ?? null;
    }
    async set(key, value, ttlSeconds) {
        this.cache.set(key, value, { ttl: ttlSeconds * 1000 });
    }
    async del(pattern) {
        const regex = new RegExp('^' + pattern.replace('*', '.*') + '$');
        const keysToDelete = [];
        for (const key of this.cache.keys()) {
            if (regex.test(key)) {
                keysToDelete.push(key);
            }
        }
        for (const key of keysToDelete) {
            this.cache.delete(key);
        }
    }
}
// 3. Export the unified Cache Instance
export const cache = process.env.REDIS_URL
    ? new RedisCache(process.env.REDIS_URL)
    : new MemoryCache();
//# sourceMappingURL=cache.js.map