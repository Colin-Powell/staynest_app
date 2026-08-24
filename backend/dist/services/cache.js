const cache = new Map();
export function getCache(key) {
    const item = cache.get(key);
    if (!item) {
        return null;
    }
    if (Date.now() > item.expiresAt) {
        cache.delete(key);
        return null;
    }
    return item.value;
}
export function setCache(key, value, ttlMs) {
    cache.set(key, {
        value,
        expiresAt: Date.now() + ttlMs,
    });
}
export function clearCache(key) {
    cache.delete(key);
}
export function clearCachePattern(pattern) {
    for (const key of cache.keys()) {
        if (key.startsWith(pattern)) {
            cache.delete(key);
        }
    }
}
//# sourceMappingURL=cache.js.map