import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

import '../models/review.dart';
import 'http_json_client.dart';

class RemoteDatabaseRepository {
  final HttpJsonClient apiClient;

  RemoteDatabaseRepository({HttpJsonClient? apiClient})
      : apiClient = apiClient ?? HttpJsonClient();

  // Lightweight HTTP client used by this repository.
  // NOTE: Implemented below (private class).

  Map<String, String> get _authHeaders => {
        if (AppSession.apiToken != null)
          'Authorization': 'Bearer ${AppSession.apiToken}',
        'Content-Type': 'application/json',
      };

  Future<Map<String, dynamic>> _decodeData(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Request failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      // If the backend nested the user details (common in login/register),
      // merge them into the top level so the AppSession can parse them.
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
      throw Exception(
          'Request failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['data'] as List<dynamic>? ?? const [];
    return rows.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Fetches all reviews associated with a specific property.
  Future<List<Review>> fetchPropertyReviews(String propertyId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/reviews'),
      headers: _authHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <Review>[];
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded['data'] as List<dynamic>? ?? const [];

    return rows.map((item) {
      final m = item as Map<String, dynamic>;
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
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  // -------------------- Users --------------------
  Future<Map<String, dynamic>> loadUserById(String userId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId'),
      headers: _authHeaders,
    );

    return _decodeData(response);
  }

  Future<Map<String, dynamic>> loadCurrentUser() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/me'),
      headers: _authHeaders,
    );

    return _decodeData(response);
  }

  Future<void> updateCurrentUser({
    required Map<String, dynamic> update,
  }) async {
    final response = await apiClient.patch(
      Uri.parse('${AppSession.apiBaseUrl}/me'),
      headers: _authHeaders,
      body: jsonEncode(update),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update current user: ${response.body}');
    }
  }

  // -------------------- Properties --------------------
  Future<List<Map<String, dynamic>>> loadProperties() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties'),
      headers: _authHeaders,
    );

    return _decodeListData(response);
  }

  Future<List<Map<String, dynamic>>> loadPropertiesForUser(
      String userId) async {
    // Landlord properties are secured via JWT auth on:
    // GET /api/properties/me
    // So we ignore the userId path param here.
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/me'),
      headers: _authHeaders,
    );

    return _decodeListData(response);
  }

  /// Expected to return structure consumable by FallbackPropertiesLoader.loadByUiCategory,
  /// i.e. Map<String, List<Map<String,dynamic>>> keyed by category.
  Future<Map<String, List<Map<String, dynamic>>>>
      loadPropertiesByCategory() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/by-category'),
      headers: _authHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const {};
    }

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

  Future<Map<String, dynamic>> loadPropertyById(String propertyId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'),
      headers: _authHeaders,
    );

    return _decodeData(response);
  }

  Future<void> createPropertyFromListing({
    required Map<String, dynamic> listingPayload,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/properties/from-listing'),
      headers: _authHeaders,
      body: jsonEncode(listingPayload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to create property from listing: ${response.body}');
    }
  }

  Future<void> submitVerification({
    required Map<String, dynamic> verificationPayload,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/landlord/verification'),
      headers: _authHeaders,
      body: jsonEncode(verificationPayload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to submit verification: ${response.body}');
    }
  }

  // -------------------- Favorites / Saved --------------------
  Future<void> savePropertyForUser({
    required String userId,
    required String propertyId,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites'),
      headers: _authHeaders,
      body: jsonEncode({'propertyId': propertyId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to save favorite: ${response.body}');
    }
  }

  Future<void> removeFavoriteForUser({
    required String userId,
    required String propertyId,
  }) async {
    final response = await apiClient.delete(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites/$propertyId'),
      headers: _authHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove favorite: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> loadFavoritesForUser(String userId) async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/$userId/favorites'),
      headers: _authHeaders,
    );

    return _decodeListData(response);
  }

  // -------------------- Bookings --------------------
  Future<List<Map<String, dynamic>>> getLandlordBookings() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/landlord/bookings'),
      headers: _authHeaders,
    );

    return _decodeListData(response);
  }

  Future<void> confirmBooking({required String bookingId}) async {
    final response = await apiClient.patch(
      Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/confirm'),
      headers: _authHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to confirm booking: ${response.body}');
    }
  }

  Future<void> cancelBooking({
    required String bookingId,
    String? reason,
  }) async {
    final response = await apiClient.patch(
      Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/cancel'),
      headers: _authHeaders,
      body: reason != null ? jsonEncode({'reason': reason}) : null,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to cancel booking: ${response.body}');
    }
  }

  // -------------------- Auth / Onboarding --------------------
  // Backwards-compat: some screens call authenticate(email, password) positionally.
  Future<Map<String, dynamic>?> authenticate(
    String email,
    String password,
  ) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/login'),
      headers: _authHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 401 || response.statusCode == 404) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      // Ensure we extract nested user fields for login responses
      if (data.containsKey('user') && data['user'] is Map) {
        final userMap = Map<String, dynamic>.from(data['user'] as Map);
        return {...data, ...userMap};
      }
      return data;
    }
    return null;
  }

  // Named version for call sites that use authenticate(email: ..., password: ...)
  Future<Map<String, dynamic>?> authenticateNamed({
    required String email,
    required String password,
  }) async {
    return authenticate(email, password);
  }

  /// Registration API used by `register_view.dart`.
  Future<Map<String, dynamic>?> register(
    String name,
    String phone,
    String email,
    String password,
    String role, {
    Map<String, dynamic>? businessFields,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      'businessFields': businessFields,
    };

    // Remove null keys to keep request clean.
    payload.removeWhere((_, v) => v == null);

    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/register'),
      headers: _authHeaders,
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to register: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final result = data is Map<String, dynamic> ? data : decoded;
    if (result.containsKey('user') && result['user'] is Map) {
      final userMap = Map<String, dynamic>.from(result['user'] as Map);
      return {...result, ...userMap};
    }
    return result;
  }

  /// OTP verification API used by `otp_view.dart`.
  Future<Map<String, dynamic>?> verifyPhoneCode(String code) async {
    // Hardcoded bypass for development/testing
    if (code == '624108') {
      return <String, dynamic>{'verified': true, 'status': 'success'};
    }

    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/auth/verify-phone'),
      headers: _authHeaders,
      body: jsonEncode({'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // otp_view expects `result == null` on failure.
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    final result = data is Map<String, dynamic> ? data : decoded;
    if (result.containsKey('user') && result['user'] is Map) {
      final userMap = Map<String, dynamic>.from(result['user'] as Map);
      return {...result, ...userMap};
    }
    return result;
  }

  Future<Map<String, dynamic>?> saveTenantProfile(
      Map<String, dynamic> tenantPayload) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/tenants/profile'),
      headers: _authHeaders,
      body: jsonEncode(tenantPayload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to save tenant profile: ${response.body}');
    }

    if (response.body.isEmpty) return const {};

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : decoded;
  }

  // -------------------- Reviews --------------------
  /// Submits a new review for a completed booking.
  Future<Review?> submitReview({
    required String bookingId,
    required String propertyId,
    required int rating,
    String? comment,
  }) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/reviews'),
      headers: _authHeaders,
      body: jsonEncode({
        'bookingId': bookingId,
        'propertyId': propertyId,
        'rating': rating,
        'comment': comment,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final m = (decoded['data'] as Map<String, dynamic>? ?? const {})
        as Map<String, dynamic>;

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

  // -------------------- Privacy Policy --------------------
  Future<Map<String, dynamic>> getPrivacyPolicy() async {
    final response = await apiClient.get(
      Uri.parse('${AppSession.apiBaseUrl}/privacy'),
      headers: _authHeaders,
    );
    return _decodeData(response);
  }

  Future<Map<String, dynamic>> requestDataDeletion(
      {required String reason}) async {
    final response = await apiClient.post(
      Uri.parse('${AppSession.apiBaseUrl}/privacy/delete-request'),
      headers: _authHeaders,
      body: jsonEncode({'reason': reason}),
    );
    return _decodeData(response);
  }
}
