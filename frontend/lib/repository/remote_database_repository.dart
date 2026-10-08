import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/models/property.dart';
import 'package:property_app/models/user.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/property_mapper.dart';

import '../models/review.dart';
import 'http_json_client.dart';
import '../services/cache_engine.dart';

class RemoteDatabaseRepository {
  final HttpJsonClient apiClient;

  RemoteDatabaseRepository({HttpJsonClient? apiClient})
      : apiClient =
            apiClient ?? HttpJsonClient(timeout: const Duration(seconds: 15));

  Future<Map<String, dynamic>> _decodeData(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      if (data.containsKey('user') && data['user'] is Map) {
        final userMap = Map<String, dynamic>.from(data['user'] as Map);
        return {...data, ...userMap};
      }
      return data;
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _decodeListData(
      http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed with status: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['data'] as List<dynamic>? ?? const [];
    return rows.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  // -------------------- Properties --------------------
  Future<List<Property>> loadProperties({int page = 1, int limit = 20}) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties').replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      ),
    );

    final rawList = await _decodeListData(response);
    return rawList.map(mapApiProperty).toList();
  }

  Future<void> loadPropertiesCached({
    int page = 1,
    int limit = 20,
    required Function(List<Map<String, dynamic>> data, bool isFromCache) onData,
  }) async {
    final cacheKey = '${CacheKeys.propertyList}_p${page}_l$limit';

    await CacheEngine.instance.handle<List<Map<String, dynamic>>>(
      key: cacheKey,
      ttl: CacheTTL.listings,
      networkFetcher: () async {
        final response = await apiClient.get(
          Uri.parse('${AppSession.apiBaseUrl}/properties').replace(
            queryParameters: {
              'page': page.toString(),
              'limit': limit.toString(),
            },
          ),
        );
        return _decodeListData(response);
      },
      onData: (data, isFromCache) {
        onData(data, isFromCache);
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadPropertiesForUser(
      String userId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties').replace(
        queryParameters: {'landlordId': userId},
      ),
    );
    return _decodeListData(response);
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      loadPropertiesByCategory() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/by-category'),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data.map((key, value) {
        final list = value as List<dynamic>? ?? const [];
        return MapEntry(
          key,
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      });
    }

    return const {};
  }

  Future<void> loadPropertyByIdCached(
    String propertyId, {
    required Function(Property data, bool isFromCache) onData,
  }) async {
    await CacheEngine.instance.handle<Map<String, dynamic>>(
      key: CacheKeys.propertyDetail(propertyId),
      ttl: CacheTTL.details,
      networkFetcher: () async {
        final response = await apiClient.get(
          Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'),
        );
        return _decodeData(response);
      },
      onData: (data, isFromCache) => onData(mapApiProperty(data), isFromCache),
    );
  }

  Future<void> createPropertyFromListing({
    required Map<String, dynamic> listingPayload,
  }) async {
    await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/properties/from-listing'),
      body: listingPayload,
    );

    await CacheEngine.instance.invalidate(CacheKeys.propertyList);
    AnalyticsService.logEvent('property_created', {'property_id': 'new'});
  }

  Future<void> updatePropertyFromListing({
    required String propertyId,
    required Map<String, dynamic> listingPayload,
  }) async {
    await apiClient.put(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'),
      body: listingPayload,
    );
    await CacheEngine.instance.invalidate(CacheKeys.propertyDetail(propertyId));
    await CacheEngine.instance.invalidate(CacheKeys.propertyList);
    await CacheEngine.instance.invalidate('landlord_props_me');
  }

  Future<void> submitVerification({
    required Map<String, dynamic> verificationPayload,
  }) async {
    await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/landlord/verification'),
      body: verificationPayload,
    );
  }

  // -------------------- Favorites / Saved --------------------
  Future<void> savePropertyForUser({
    required String userId,
    required String propertyId,
  }) async {
    await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites'),
      body: {'propertyId': propertyId},
    );
    try {
      await apiClient.post(
        Uri.parse('${AppSession.apiBaseUrl}/analytics/track'),
        body: {'eventType': 'property_save', 'propertyId': propertyId},
      );
    } catch (_) {}
    AnalyticsService.logListingInteraction(AnalyticsEvents.listingSave,
        listingId: propertyId);
  }

  Future<void> removeFavoriteForUser({
    required String userId,
    required String propertyId,
  }) async {
    await apiClient.delete(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites/$propertyId'),
    );
  }

  Future<List<Map<String, dynamic>>> loadFavoritesForUser(String userId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites'),
    );
    return _decodeListData(response);
  }

  // -------------------- Bookings --------------------
  Future<List<Map<String, dynamic>>> getLandlordBookings() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/landlord/bookings'),
    );
    return _decodeListData(response);
  }

  Future<void> confirmBooking({required String bookingId}) async {
    await apiClient.patch(
      Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/confirm'),
    );
  }

  Future<void> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    await apiClient.patch(
      Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/cancel'),
      body: reason != null ? {'reason': reason} : null,
    );
  }

  // -------------------- Reviews --------------------

  Future<List<Review>> fetchPropertyReviews(String propertyId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/reviews'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <Review>[];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['data'] as List<dynamic>? ?? const [];

    return rows.map((item) {
      final m = item as Map<String, dynamic>;
      final reviewerData = m['reviewer'] as Map<String, dynamic>?;

      return Review(
        id: m['id']?.toString() ?? 'unknown',
        bookingId:
            m['booking_id']?.toString() ?? m['bookingId']?.toString() ?? '',
        propertyId:
            m['property_id']?.toString() ?? m['propertyId']?.toString() ?? '',
        reviewerId:
            m['reviewer_id']?.toString() ?? m['reviewerId']?.toString() ?? '',
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        comment: m['comment']?.toString(),
        reviewer: reviewerData != null
            ? User(
                name: reviewerData['name']?.toString() ?? 'Anonymous',
                avatar: reviewerData['avatar']?.toString() ?? '',
                id: '',
              )
            : (m['reviewer_name'] != null
                ? User(
                    name: m['reviewer_name'].toString(),
                    avatar: m['reviewer_avatar']?.toString() ?? '',
                    id: '',
                  )
                : null),
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  /// Fetches live rating summary for a property by reusing the reviews endpoint.
  /// Returns a record with the computed average and count.
  /// Falls back to ({rating: 0.0, count: 0}) on any error so callers can
  /// gracefully fall back to the model's seeded values.
  Future<({double rating, int count})> fetchRatingSummary(
      String propertyId) async {
    try {
      final reviews = await fetchPropertyReviews(propertyId);
      if (reviews.isEmpty) return (rating: 0.0, count: 0);
      final avg =
          reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      return (rating: avg, count: reviews.length);
    } catch (_) {
      return (rating: 0.0, count: 0);
    }
  }

  /// Fetches live rating summaries for multiple properties in parallel.
  /// Returns a map of propertyId → ({rating, count}).
  /// Properties that fail silently are omitted from the map so callers
  /// fall back to model values.
  Future<Map<String, ({double rating, int count})>> fetchRatingSummaries(
      List<String> propertyIds) async {
    final results = await Future.wait(
      propertyIds.map((id) async {
        final summary = await fetchRatingSummary(id);
        // Only include if there are actual reviews — zero means
        // either no reviews or a failed fetch; both cases should
        // fall back to the model's seeded value in the UI.
        return MapEntry(id, summary);
      }),
    );
    return Map.fromEntries(results);
  }

  Future<Review?> submitReview({
    required String bookingId,
    required String propertyId,
    required int rating,
    String? comment,
  }) async {
    final url = '${AppSession.apiBaseUrl}/properties/reviews';
    final response = await apiClient.post(
      Uri.parse(url),
      body: {
        'bookingId': bookingId,
        'propertyId': propertyId,
        'rating': rating,
        'comment': comment,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    // Invalidate caches so list views and detail views refresh their rating summaries
    await CacheEngine.instance.invalidate(CacheKeys.propertyList);
    await CacheEngine.instance.invalidate(CacheKeys.propertyDetail(propertyId));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final m = (decoded['data'] as Map<String, dynamic>? ?? const {});

    return Review(
      id: m['id']?.toString() ?? 'generated_id',
      bookingId: m['booking_id']?.toString() ?? bookingId,
      propertyId: m['property_id']?.toString() ?? propertyId,
      reviewerId: m['reviewer_id']?.toString() ?? 'current_user',
      rating: (m['rating'] as num?)?.toInt() ?? rating,
      comment: m['comment']?.toString() ?? comment,
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<Map<String, dynamic>> getReviewEligibility(String propertyId) async {
    final response = await apiClient.get(
      Uri.parse(
          '${AppSession.apiBaseUrl}/properties/$propertyId/review-eligibility'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not check review eligibility.');
    }
    return Map<String, dynamic>.from(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  // -------------------- Auth / Onboarding --------------------
  Future<Map<String, dynamic>?> authenticate(
    String email,
    String password, {
    String? portal,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/login'),
      body: {'email': email, 'password': password, if (portal != null) 'portal': portal},
    );

    if (response.statusCode == 401 || response.statusCode == 404) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      if (data.containsKey('user') && data['user'] is Map) {
        final userMap = Map<String, dynamic>.from(data['user'] as Map);
        return {...data, ...userMap};
      }
      return data;
    }
    return null;
  }

  Future<Map<String, dynamic>?> authenticateNamed({
    required String email,
    required String password,
  }) async {
    return authenticate(email, password);
  }

  Future<Map<String, dynamic>?> register(
    String name,
    String phone,
    String email,
    String password,
    String role, {
    Map<String, dynamic>? businessFields,
    String? referralCode,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
    };
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      payload['referralCode'] = referralCode.trim();
    }
    if (businessFields != null) {
      payload.addAll(businessFields);
    }

    payload.removeWhere((_, v) => v == null);

    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/register'),
      body: payload,
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final result = data is Map<String, dynamic> ? data : decoded;

    if (result.containsKey('user') && result['user'] is Map) {
      final userMap = Map<String, dynamic>.from(result['user'] as Map);
      return {...result, ...userMap};
    }
    return result;
  }

  Future<Map<String, dynamic>?> sendOtpToEmail(String email) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/email/send-otp'),
      body: {'email': email},
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : decoded;
  }

  Future<Map<String, dynamic>?> revokeOtp(String email) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/email/revoke-otp'),
      body: {'email': email},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : decoded;
  }

  Future<Map<String, dynamic>?> changeEmail(String email) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/change-email'),
      body: {'email': email},
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final result = data is Map<String, dynamic> ? data : decoded;
    if (result['user'] is Map) {
      final user = Map<String, dynamic>.from(result['user'] as Map);
      return {...result, ...user};
    }
    return result;
  }

  Future<Map<String, dynamic>?> verifyOtpCode(String email, String code) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/email/verify-otp'),
      body: {'email': email, 'code': code},
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final result = data is Map<String, dynamic> ? data : decoded;

    if (result.containsKey('user') && result['user'] is Map) {
      final userMap = Map<String, dynamic>.from(result['user'] as Map);
      return {...result, ...userMap};
    }
    return result;
  }

  Future<Map<String, dynamic>?> verifyPhoneCode(String code) async {
    final email = AppSession.currentUserEmail?.trim();
    if (email == null || email.isEmpty) {
      return <String, dynamic>{'verified': false, 'status': 'missing_email'};
    }
    return verifyOtpCode(email, code);
  }

  /// Returns the current authenticated tenant profile (preferences), or `null` if missing.
  /// Backend: GET /api/tenant_profiles/me
  Future<Map<String, dynamic>?> fetchTenantProfileMe() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/tenant_profiles/me'),
    );

    if (response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<Map<String, dynamic>?> saveTenantProfile(
    Map<String, dynamic> tenantPayload,
  ) async {
    // NOTE: backend expects POST /api/tenant_profiles (router root)
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/tenant_profiles'),
      body: tenantPayload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : decoded;
  }

  // -------------------- Privacy --------------------
  Future<Map<String, dynamic>> getPrivacyPolicy() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/privacy'),
    );
    return _decodeData(response);
  }

  Future<Map<String, dynamic>> requestDataDeletion({
    required String reason,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/privacy/delete-request'),
      body: {'reason': reason},
    );
    return _decodeData(response);
  }

  // -------------------- Users --------------------
  Future<Map<String, dynamic>> loadUserByIdLegacy(String userId) async =>
      loadUserById(userId);

  Future<Map<String, dynamic>> loadUserById(String userId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId'),
    );
    return _decodeData(response);
  }

  Future<Map<String, dynamic>> loadCurrentUserLegacy() async =>
      loadCurrentUser();

  Future<void> loadCurrentUserCached({
    required Function(Map<String, dynamic> data, bool isFromCache) onData,
  }) async {
    if (AppSession.currentUserId == null) return;

    await CacheEngine.instance.handle<Map<String, dynamic>>(
      key: CacheKeys.userProfile(AppSession.currentUserId!),
      ttl: CacheTTL.profile,
      networkFetcher: () async {
        return loadUserById(AppSession.currentUserId!);
      },
      onData: onData,
    );
  }

  Future<Map<String, dynamic>> loadCurrentUser() async {
    if (AppSession.apiToken == null) {
      throw Exception('No authenticated session');
    }
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/me'),
    );
    return _decodeData(response);
  }

  Future<Map<String, dynamic>> updateCurrentUser({
    required Map<String, dynamic> update,
  }) async {
    final url = '${AppSession.apiBaseUrl}/users/profile';
    if (kDebugMode) {
      debugPrint('[Repository] Updating user at: $url with $update');
    }

    final response = await apiClient.patch(
      Uri.parse(url),
      body: update,
    );

    final data = await _decodeData(response);

    if (AppSession.currentUserId != null) {
      await CacheEngine.instance.invalidate(
        CacheKeys.userProfile(AppSession.currentUserId!),
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> loadPropertyById(String propertyId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'),
    );
    return _decodeData(response);
  }
}
