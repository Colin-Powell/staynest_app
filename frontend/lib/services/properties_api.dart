import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/screens/home/cache_engine.dart';
import 'package:uuid/uuid.dart';

class PropertiesApi {
  static Future<void> trackPropertyShare(String propertyId) async {
    final client = _client();
    await client.postJson('/analytics/track', body: {
      'eventType': 'property_share',
      'propertyId': propertyId,
      'metadata': {'source': 'native_share'},
    });
  }

  static Future<void> recordPropertyView(String propertyId) async {
    try {
      final client = _client();
      await client.postJson('/properties/$propertyId/view');
      await client.postJson('/analytics/track',
          body: {'eventType': 'property_view', 'propertyId': propertyId});
      // Invalidate the cache so the home screen reflects the new view immediately
      await CacheEngine.instance.invalidate(
          'props_recently_viewed_${AppSession.currentUserId ?? 'guest'}');
    } catch (e) {
      // Silently fail for analytics
    }
  }

  /// Boost a property
  static Future<Map<String, dynamic>> boostProperty(
      String propertyId, String packageType,
      {String? idempotencyKey}) async {
    final client = _client();
    final response = await client.postJson('/promotions/boost', body: {
      'property_id': propertyId,
      'package_type': packageType,
      'idempotency_key': idempotencyKey ?? const Uuid().v4(),
    });
    return response['data'] ?? {};
  }

  /// Initiate M-Pesa payment for boost
  static Future<Map<String, dynamic>> initiatePayment({
    required String propertyId,
    required String packageType,
    required String phone,
    String paymentMethod = 'mpesa',
  }) async {
    final client = _client();
    final response = await client.postJson('/payments/boost-initiate', body: {
      'propertyId': propertyId,
      'packageType': packageType,
      'phone': phone,
      'paymentMethod': paymentMethod,
    });
    return response;
  }

  /// Get payment transaction status
  static Future<Map<String, dynamic>> getPaymentStatus(
      String transactionId) async {
    try {
      final client = _client();
      final response = await client.getJson('/payments/status/$transactionId');
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Get payment history for user
  static Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final client = _client();
      final response = await client.getJson('/payments/history');
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get active promotions for landlord

  static Future<List<Map<String, dynamic>>> getRelevantPromotions() async {
    try {
      final client = _client();
      final response = await client.getJson('/promotions/relevant');
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getActivePromotions() async {
    try {
      final client = _client();
      final response = await client.getJson('/promotions/me');
      final data = response['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static ApiClient _client() {
    return ApiClient(
      baseUrl: AppSession.apiBaseUrl,
      defaultHeaders: AppSession.apiToken != null
          ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
          : null,
    );
  }

  /// Fetch all properties for the current landlord.
  static Future<List<Map<String, dynamic>>> getLandlordProperties() async {
    return CacheEngine.instance.getOrFetch<List<Map<String, dynamic>>>(
      key: 'landlord_props_me',
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties/me');
        final data = response['data'] as List<dynamic>? ?? [];
        return data.cast<Map<String, dynamic>>();
      },
    );
  }

  /// Fetch a single property by ID.
  static Future<Map<String, dynamic>> getPropertyById(String propertyId) async {
    return CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
      key: CacheKeys.propertyDetail(propertyId),
      ttl: CacheTTL.details,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties/$propertyId');
        return Map<String, dynamic>.from(response['data'] as Map);
      },
    );
  }

  /// Fetch all properties with optional filters.
  static Future<List<Map<String, dynamic>>> getAllProperties({
    String? category,
    String? city,
    double? lat,
    double? lng,
    double? proximity,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (city != null) params['city'] = city;
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (proximity != null) params['proximity'] = proximity.toString();

    final cacheKey = 'props_all_$params';

    return CacheEngine.instance.getOrFetch<List<Map<String, dynamic>>>(
      key: cacheKey,
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties',
            queryParams: params.isNotEmpty ? params : null);
        final data = response['data'] as List<dynamic>? ?? [];
        return data.cast<Map<String, dynamic>>();
      },
    );
  }

  /// Create a new property listing.
  static Future<Map<String, dynamic>> createProperty(
      Map<String, dynamic> payload) async {
    final client = _client();
    final response = await client.postJson('/properties', body: payload);
    await CacheEngine.instance.invalidate('landlord_props_me');
    return response['data'] as Map<String, dynamic>;
  }

  /// Update an existing property.
  static Future<Map<String, dynamic>> updateProperty(
    String propertyId,
    Map<String, dynamic> payload,
  ) async {
    final client = _client();
    final response = await client.putJson(
      '/properties/$propertyId',
      body: payload,
    );
    await CacheEngine.instance.invalidate(CacheKeys.propertyDetail(propertyId));
    await CacheEngine.instance.invalidate('landlord_props_me');
    await CacheEngine.instance.invalidate(CacheKeys.propertyList);
    return response['data'] as Map<String, dynamic>;
  }

  /// Delete a property.
  static Future<void> deleteProperty(String propertyId) async {
    final client = _client();
    await client.deleteJson('/properties/$propertyId');
    await CacheEngine.instance.invalidate(CacheKeys.propertyDetail(propertyId));
    await CacheEngine.instance.invalidate('landlord_props_me');
  }

  /// Fetch recently viewed properties for the current tenant.
  static Future<List<Map<String, dynamic>>> getRecentlyViewed() async {
    return CacheEngine.instance.getOrFetch<List<Map<String, dynamic>>>(
      key: 'props_recently_viewed_${AppSession.currentUserId ?? 'guest'}',
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties/me/recently-viewed');
        final data = response['data'] as List<dynamic>? ?? [];
        return data.cast<Map<String, dynamic>>();
      },
    );
  }

  static Future<Map<String, dynamic>> getCategories() async {
    return CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
      key: 'props_categories',
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties/categories');
        return response['data'] as Map<String, dynamic>? ?? {};
      },
    );
  }

  /// Fetch recommendations for the current tenant.
  static Future<List<Map<String, dynamic>>> getRecommendations() async {
    return CacheEngine.instance.getOrFetch<List<Map<String, dynamic>>>(
      key: 'props_recommendations_${AppSession.currentUserId ?? 'guest'}',
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final client = _client();
        final response = await client.getJson('/properties/recommendations');
        final data = response['data'] as List<dynamic>? ?? [];
        return data.cast<Map<String, dynamic>>();
      },
    );
  }
}
