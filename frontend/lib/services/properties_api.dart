import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

class PropertiesApi {
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
    final client = _client();
    final response = await client.getJson('/properties/me');
    final data = response['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetch a single property by ID.
  static Future<Map<String, dynamic>> getPropertyById(String propertyId) async {
    final client = _client();
    final response = await client.getJson('/properties/$propertyId');
    return response['data'] as Map<String, dynamic>;
  }

  /// Fetch all properties with optional filters.
  static Future<List<Map<String, dynamic>>> getAllProperties({
    String? category,
    String? city,
    double? lat,
    double? lng,
    double? proximity,
  }) async {
    final client = _client();
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (city != null) params['city'] = city;
    if (lat != null) params['lat'] = lat.toString();
    if (lng != null) params['lng'] = lng.toString();
    if (proximity != null) params['proximity'] = proximity.toString();

    final response = await client.getJson(
      '/properties',
      queryParams: params,
    );
    final data = response['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Create a new property listing.
  static Future<Map<String, dynamic>> createProperty(
      Map<String, dynamic> payload) async {
    final client = _client();
    final response = await client.postJson('/properties', body: payload);
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
    return response['data'] as Map<String, dynamic>;
  }

  /// Delete a property.
  static Future<void> deleteProperty(String propertyId) async {
    final client = _client();
    await client.deleteJson('/properties/$propertyId');
  }

  /// Fetch recommendations for the current tenant.
  static Future<List<Map<String, dynamic>>> getRecommendations() async {
    final client = _client();
    final response = await client.getJson('/properties/recommendations');
    final data = response['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }
}
