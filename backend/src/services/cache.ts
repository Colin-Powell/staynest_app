import { createClient } from 'redis';
import { LRUCache } from 'lru-cache';
import dotenv from 'dotenv';

dotenv.config();

// Define a unified interface for the cache
export interface ICache {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttlSeconds: number): Promise<void>;
  del(pattern: string): Promise<void>;
}

// 1. Redis Cache Implementation
class RedisCache implements ICache {
  private client: ReturnType<typeof createClient>;
  private isConnected = false;

  constructor(url: string) {
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

  async get(key: string): Promise<string | null> {
    if (!this.isConnected) return null;
    try {
      return await this.client.get(key);
    } catch {
      return null;
    }
  }

  async set(key: string, value: string, ttlSeconds: number): Promise<void> {
    if (!this.isConnected) return;
    try {
      await this.client.set(key, value, { EX: ttlSeconds });
    } catch {
      // ignore
    }
  }

  async del(pattern: string): Promise<void> {
    if (!this.isConnected) return;
    try {
      const keys = await this.client.keys(pattern);
      if (keys.length > 0) {
        await this.client.del(keys);
      }
    } catch {
      // ignore
    }
  }
}

// 2. Local Memory Fallback Cache
class MemoryCache implements ICache {
  private cache: LRUCache<string, string>;

  constructor() {
    this.cache = new LRUCache({
      max: 500, // max items
      ttl: 1000 * 60 * 60, // default 1 hour
    });
    console.log('[MemoryCache] Initialized In-Memory LRU Cache Fallback');
  }

  async get(key: string): Promise<string | null> {
    return this.cache.get(key) ?? null;
  }

  async set(key: string, value: string, ttlSeconds: number): Promise<void> {
    this.cache.set(key, value, { ttl: ttlSeconds * 1000 });
  }

  async del(pattern: string): Promise<void> {
    const regex = new RegExp('^' + pattern.replace('*', '.*') + '$');
    const keysToDelete: string[] = [];
    
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
export const cache: ICache = process.env.REDIS_URL 
  ? new RedisCache(process.env.REDIS_URL)
  : new MemoryCache();
