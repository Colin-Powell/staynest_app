import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

class CacheEntry {
  final dynamic data;
  final DateTime createdAt;
  final Duration ttl;
  final int version;

  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
    required this.version,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;

  Map<String, dynamic> toJson() => {
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'ttl': ttl.inMilliseconds,
        'version': version,
      };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
        data: json['data'],
        createdAt: DateTime.parse(json['createdAt']),
        ttl: Duration(milliseconds: json['ttl']),
        version: json['version'] ?? 0,
      );
}

class CacheEngine {
  static final CacheEngine instance = CacheEngine._();
  CacheEngine._();

  static const int _currentVersion = 1; // Engine version for schema migration
  static const String _boxName = 'staynest_cache';
  Box? _box;

  // In-memory speed layer
  final Map<String, CacheEntry> _memoryCache = {};

  // Request Deduplication: Prevents multiple simultaneous API calls for the same key
  final Map<String, Future<dynamic>> _inFlightRequests = {};

  /// Initializes Hive and opens the cache box
  Future<void> _init() async {
    if (_box != null && _box!.isOpen) return;
    if (!kIsWeb && !Hive.isAdapterRegistered(0)) {
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);
    }
    _box = await Hive.openBox(_boxName);
  }

  /// Main entry point for data requests.
  /// [onData] will be called with cached data first (if available),
  /// then again with fresh data from the network.
  Future<void> handle<T>({
    required String key,
    required Future<T> Function() networkFetcher,
    required Function(T data, bool isFromCache) onData,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    await _init();

    CacheEntry? entry;

    // 1. Check Memory Cache (L1)
    if (_memoryCache.containsKey(key)) {
      entry = _memoryCache[key]!;
    } else {
      // 2. Check Persistent Cache (L2) - Using Hive for binary performance
      final raw = _box?.get(key);
      if (raw != null) {
        try {
          // Typed Serialization: Hive stores Map natively in binary format
          final dynamic decoded = raw;

          // Older/other callers may have stored data in different shapes.
          // We normalize to the CacheEntry JSON structure.
          Map<String, dynamic> map;
          if (decoded is Map<String, dynamic>) {
            map = decoded;
          } else if (decoded is Map) {
            map = Map<String, dynamic>.from(decoded);
          } else {
            throw FormatException('Unexpected cache payload for $key');
          }

          final loadedEntry = CacheEntry.fromJson(map);

          // Versioning Check: Ensure cached data schema matches current engine
          if (loadedEntry.version == _currentVersion) {
            _memoryCache[key] = loadedEntry;
            entry = loadedEntry;
          } else {
            debugPrint(
                '[CacheEngine] Version mismatch for $key. Invalidating.');
            await invalidate(key);
          }
        } catch (e) {
          debugPrint('[CacheEngine] Corrupt cache for $key');
        }
      }
    }

    if (entry != null) {
      try {
        dynamic data = entry.data;

        // Hive and JSON deserialization often lose type specificity for collections.
        // We re-cast to the expected type if we detect a mismatch for common API types.
        if (data is List && T == List<Map<String, dynamic>>) {
          data = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data is Map && T == Map<String, dynamic>) {
          data = Map<String, dynamic>.from(data);
        }

        onData(data as T, true);
        if (!entry.isExpired) return; // Fresh enough
      } catch (e) {
        debugPrint('[CacheEngine] Cache cast failed for $key: $e');
        // If casting fails, we fall through to the network fetcher below.
      }
    }

    // 3. Stale-While-Revalidate: Fetch fresh data from Network (L3)
    try {
      final T freshData = await _deduplicatedFetch(key, networkFetcher);
      await _save(key, freshData, ttl);
      onData(freshData, false);
    } catch (e) {
      debugPrint('[CacheEngine] Network fetch failed for $key: $e');

      // FAILURE FALLBACK: If network fails, the user continues to see stale data.
      // If no data was found in cache (entry == null), the UI should handle the error.
    }
  }

  /// Prevents multiple API calls for the same resource at the same time
  Future<T> _deduplicatedFetch<T>(
      String key, Future<T> Function() fetcher) async {
    if (_inFlightRequests.containsKey(key)) {
      return await _inFlightRequests[key] as T;
    }

    final Future<T> request = fetcher();
    _inFlightRequests[key] = request;

    try {
      return await request;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<void> _save(String key, dynamic data, Duration ttl) async {
    final entry = CacheEntry(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
      version: _currentVersion,
    );

    // Save to Memory
    _memoryCache[key] = entry;

    // Save to Disk
    await _box?.put(key, entry.toJson());
  }

  /// Invalidate specific keys (e.g., when a user updates a property)
  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _box?.delete(key);
  }

  /// Clear everything (e.g., on Logout)
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _box?.clear();
  }
}

/// TTL Presets for the application
class CacheTTL {
  static const listings = Duration(minutes: 5);
  static const details = Duration(minutes: 30);
  static const profile = Duration(hours: 2);
  static const staticConfig = Duration(days: 7);
}

/// Cache Key Factory to ensure consistency
class CacheKeys {
  static String propertyList = 'props_all';
  static String propertyDetail(String id) => 'prop_detail_$id';
  static String userProfile(String id) => 'user_profile_$id';
  static String search(String query) => 'search_${query.replaceAll(' ', '_')}';
}
