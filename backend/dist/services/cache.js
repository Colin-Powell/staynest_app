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
        this.connectionPromise = this.client.connect().then(() => undefined);
        this.connectionPromise.catch(console.error);
    }
    async get(key) {
        try {
            await this.connectionPromise;
            if (!this.isConnected)
                return null;
            return await this.client.get(key);
        }
        catch {
            return null;
        }
    }
    async set(key, value, ttlSeconds) {
        try {
            await this.connectionPromise;
            if (!this.isConnected)
                return;
            await this.client.set(key, value, { EX: ttlSeconds });
        }
        catch {
            // ignore
        }
    }
    async setIfAbsent(key, value, ttlSeconds) {
        try {
            await this.connectionPromise;
            if (!this.isConnected)
                return false;
            const result = await this.client.set(key, value, { EX: ttlSeconds, NX: true });
            return result === 'OK';
        }
        catch {
            return false;
        }
    }
    async del(pattern) {
        try {
            await this.connectionPromise;
            if (!this.isConnected)
                return;
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
    async setIfAbsent(key, value, ttlSeconds) {
        if (this.cache.has(key))
            return false;
        this.cache.set(key, value, { ttl: ttlSeconds * 1000 });
        return true;
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