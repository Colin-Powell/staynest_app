import 'package:flutter/foundation.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/api_client.dart';

class RemoteDatabaseRepository {
  final ApiClient apiClient;

  RemoteDatabaseRepository({ApiClient? apiClient})
      : apiClient = apiClient ??
            ApiClient(
              baseUrl: AppSession.apiBaseUrl,
              defaultHeaders: AppSession.apiToken != null
                  ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
                  : null,
            ) {
    if (kDebugMode) {
      debugPrint('RemoteDatabaseRepository baseUrl: ${this.apiClient.baseUrl}');
    }
  }

  Future<List<Map<String, dynamic>>> loadProperties() async {
    final response = await apiClient.getJson('/properties');
    return _extractList(response);
  }

  Future<Map<String, dynamic>?> loadCurrentUser() async {
    final response = await apiClient.getJson('/users/me');
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      final userData = payload['user'] ?? payload;
      return userData is Map<String, dynamic>
          ? Map<String, dynamic>.from(userData)
          : null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateCurrentUser(
    String name,
    String email,
    String phone,
  ) async {
    final response = await apiClient.patchJson(
      '/users/me',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
      },
    );

    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      final userData = payload['user'] ?? payload;
      return userData is Map<String, dynamic>
          ? Map<String, dynamic>.from(userData)
          : null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> verifyPhoneCode(String code) async {
    final response = await apiClient.postJson(
      '/auth/verify',
      body: {'code': code},
    );
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic> &&
        payload['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload['user']);
    }
    return payload is Map<String, dynamic> ? payload : null;
  }

  Future<Map<String, dynamic>?> createProperty(
    Map<String, dynamic> property,
  ) async {
    final response = await apiClient.postJson(
      '/properties',
      body: property,
    );
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  Future<Map<String, dynamic>?> submitVerification(
      Map<String, dynamic> documents, Map<String, dynamic> property) async {
    final response = await apiClient.postJson(
      '/verifications',
      body: {'documents': documents, 'property': property},
    );
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  // Compatibility helper for existing listing UI.
  Future<Map<String, dynamic>?> createPropertyFromListing(
    Map<String, dynamic> property,
  ) async {
    return createProperty(property);
  }

  Future<Map<String, dynamic>?> loadMyVerification() async {
    final response = await apiClient.getJson('/verifications/me');
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      loadPropertiesByCategory() async {
    final response = await apiClient.getJson('/properties/categories');
    return _extractMap(response);
  }

  Future<List<Map<String, dynamic>>> loadUsers() async {
    final response = await apiClient.getJson('/users');
    return _extractList(response);
  }

  Future<Map<String, dynamic>?> authenticate(
    String email,
    String password,
  ) async {
    final response = await apiClient.postJson(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.isEmpty) {
      return null;
    }

    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic> &&
        payload['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload['user'])
        ..['token'] = payload['token'] ?? payload['data']?['token'];
    }
    return payload is Map<String, dynamic> ? payload : null;
  }

  Future<Map<String, dynamic>?> getTenantProfile() async {
    final response = await apiClient.getJson('/tenant_profiles/me');
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  Future<Map<String, dynamic>?> saveTenantProfile(
      Map<String, dynamic> profile) async {
    final response =
        await apiClient.postJson('/tenant_profiles', body: profile);
    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload);
    }
    return null;
  }

  Future<Map<String, dynamic>?> register(
    String name,
    String phone,
    String email,
    String password,
    String role, {
    Map<String, dynamic>? businessFields,
  }) async {
    final body = {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
      if (businessFields != null) ...businessFields,
    };
    final response = await apiClient.postJson(
      '/auth/register',
      body: body,
    );

    final payload = response['data'] ?? response;
    if (payload is Map<String, dynamic> &&
        payload['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(payload['user'])
        ..['token'] = payload['token'] ?? payload['data']?['token'];
    }
    return payload is Map<String, dynamic> ? payload : null;
  }

  Future<List<Map<String, dynamic>>> loadPropertiesForUser(
      String userId) async {
    final response = await apiClient.getJson('/users/$userId/properties');
    return _extractList(response);
  }

  Future<Map<String, dynamic>?> loadUserById(String userId) async {
    final response = await apiClient.getJson('/users/$userId');
    final payload = response['data'];
    return payload is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload)
        : null;
  }

  /// Load a full property record by id.
  /// Used for PropertyDetails/BookingView so we do not rely on local mock data.
  Future<Map<String, dynamic>?> loadPropertyById(String propertyId) async {
    final response = await apiClient.getJson('/properties/$propertyId');
    return response['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(response['data'])
        : null;
  }

  Future<List<Map<String, dynamic>>> loadFavoritesForUser(String userId) async {
    final response = await apiClient.getJson('/users/$userId/favorites');
    return _extractList(response);
  }

  Future<bool> savePropertyForUser(String userId, String propertyId) async {
    final response = await apiClient.postJson(
      '/users/$userId/favorites',
      body: {'propertyId': propertyId},
    );
    return response['data'] is Map<String, dynamic> &&
        response['data']['saved'] == true;
  }

  Future<bool> removeFavoriteForUser(String userId, String propertyId) async {
    final response =
        await apiClient.deleteJson('/users/$userId/favorites/$propertyId');
    return response['data'] is Map<String, dynamic> &&
        response['data']['saved'] == false;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final raw = response['data'] ??
        response['properties'] ??
        response['items'] ??
        response;
    if (raw is List) {
      return _castList(raw);
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, List<Map<String, dynamic>>> _extractMap(
      Map<String, dynamic> response) {
    final raw = response['data'] ?? response['categories'] ?? response;
    if (raw is Map<String, dynamic>) {
      return raw.map((key, value) {
        if (value is List) {
          return MapEntry(key, _castList(value));
        }
        return MapEntry(key, <Map<String, dynamic>>[]);
      });
    }
    return <String, List<Map<String, dynamic>>>{};
  }

  // Booking methods
  Future<Map<String, dynamic>> createBooking({
    required String propertyId,
    required String checkInDate,
    required String checkOutDate,
    required double totalPrice,
    String? notes,
  }) async {
    final response = await apiClient.postJson(
      '/bookings',
      body: {
        'propertyId': propertyId,
        'checkInDate': checkInDate,
        'checkOutDate': checkOutDate,
        'totalPrice': totalPrice,
        if (notes != null) 'notes': notes,
      },
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getTenantBookings() async {
    final response = await apiClient.getJson('/bookings/tenant');
    return _extractList(response);
  }

  Future<List<Map<String, dynamic>>> getLandlordBookings() async {
    final response = await apiClient.getJson('/bookings/landlord');
    return _extractList(response);
  }

  Future<Map<String, dynamic>> confirmBooking(String bookingId) async {
    final response = await apiClient.patchJson(
      '/bookings/$bookingId/confirm',
      body: {},
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId,
      {String? reason}) async {
    final response = await apiClient.patchJson(
      '/bookings/$bookingId/cancel',
      body: {
        if (reason != null) 'reason': reason,
      },
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    final response = await apiClient.getJson('/bookings/$bookingId');
    return response['data'] is Map<String, dynamic> ? response['data'] : null;
  }

  List<Map<String, dynamic>> _castList(List<dynamic> raw) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
