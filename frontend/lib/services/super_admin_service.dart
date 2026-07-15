import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

class SuperAdminService {
  static ApiClient _client() {
    return ApiClient(
      baseUrl: AppSession.apiBaseUrl,
      defaultHeaders: AppSession.apiToken != null
          ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
          : null,
    );
  }

  static Future<Map<String, dynamic>> fetchOverview() async {
    final response = await _client().getJson('/admin/overview');
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  static Future<List<Map<String, dynamic>>> fetchUsers({int limit = 10}) async {
    final response = await _client().getJson(
      '/admin/users',
      queryParams: {'limit': limit.toString()},
    );
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchProperties(
      {int limit = 10}) async {
    final response = await _client().getJson(
      '/admin/properties',
      queryParams: {'limit': limit.toString()},
    );
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchKyc({int limit = 10}) async {
    final response = await _client().getJson(
      '/admin/kyc',
      queryParams: {'limit': limit.toString()},
    );
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> updateKycStatus(
    String id, {
    required String status,
    String? adminNotes,
  }) async {
    final response = await _client().patchJson(
      '/admin/kyc/$id',
      body: {
        'status': status,
        if (adminNotes != null) 'admin_notes': adminNotes,
      },
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  static Future<Map<String, dynamic>> updatePropertyStatus(
    String id, {
    required String status,
  }) async {
    final response = await _client().patchJson(
      '/admin/properties/$id/status',
      body: {'status': status},
    );

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}
