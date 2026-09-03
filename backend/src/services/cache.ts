import { createClient } from 'redis';
import { LRUCache } from 'lru-cache';
import dotenv from 'dotenv';

dotenv.config();

// Define a unified interface for the cache
export interface ICache {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttlSeconds: number): Promise<void>;
  setIfAbsent(key: string, value: string, ttlSeconds: number): Promise<boolean>;
  del(pattern: string): Promise<void>;
}

// 1. Redis Cache Implementation
class RedisCache implements ICache {
  private client: ReturnType<typeof createClient>;
  private isConnected = false;
  private connectionPromise: Promise<void>;

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

    this.connectionPromise = this.client.connect().then(() => undefined);
    this.connectionPromise.catch(console.error);
  }

  async get(key: string): Promise<string | null> {
    try {
      await this.connectionPromise;
      if (!this.isConnected) return null;
      return await this.client.get(key);
    } catch {
      return null;
    }
  }

  async set(key: string, value: string, ttlSeconds: number): Promise<void> {
    try {
      await this.connectionPromise;
      if (!this.isConnected) return;
      await this.client.set(key, value, { EX: ttlSeconds });
    } catch {
      // ignore
    }
  }

  async setIfAbsent(key: string, value: string, ttlSeconds: number): Promise<boolean> {
    try {
      await this.connectionPromise;
      if (!this.isConnected) return false;
      const result = await this.client.set(key, value, { EX: ttlSeconds, NX: true });
      return result === 'OK';
    } catch {
      return false;
    }
  }

  async del(pattern: string): Promise<void> {
    try {
      await this.connectionPromise;
      if (!this.isConnected) return;
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

  async setIfAbsent(key: string, value: string, ttlSeconds: number): Promise<boolean> {
    if (this.cache.has(key)) return false;
    this.cache.set(key, value, { ttl: ttlSeconds * 1000 });
    return true;
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
