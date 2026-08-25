import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

class SuperAdminService {
  static ApiClient _client() => ApiClient(
        baseUrl: AppSession.apiBaseUrl,
        defaultHeaders: AppSession.apiToken != null
            ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
            : null,
      );

  static Map<String, dynamic> _data(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> response) {
    final data = response['data'];
    return data is List
        ? data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : [];
  }

  static Future<Map<String, dynamic>> fetchOverview() async =>
      _data(await _client().getJson('/admin/overview'));

  static Future<List<Map<String, dynamic>>> fetchUsers({
    int limit = 10,
    int offset = 0,
    String? search,
    String? role,
  }) async =>
      _list(await _client().getJson('/admin/users', queryParams: {
        'limit': '$limit',
        'offset': '$offset',
        if (search != null && search.isNotEmpty) 'search': search,
        if (role != null && role.isNotEmpty) 'role': role,
      }));

  static Future<List<Map<String, dynamic>>> fetchProperties({
    int limit = 10,
    int offset = 0,
    String? status,
    String? search,
  }) async =>
      _list(await _client().getJson('/admin/properties', queryParams: {
        'limit': '$limit',
        'offset': '$offset',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      }));

  static Future<List<Map<String, dynamic>>> fetchKyc({
    int limit = 10,
    int offset = 0,
    String? status,
    String? search,
  }) async =>
      _list(await _client().getJson('/admin/kyc', queryParams: {
        'limit': '$limit',
        'offset': '$offset',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
      }));

  static Future<Map<String, dynamic>> updateKycStatus(
    String id, {
    required String status,
    String? adminNotes,
  }) async =>
      _data(await _client().patchJson('/admin/kyc/$id', body: {
        'status': status,
        if (adminNotes != null) 'admin_notes': adminNotes,
      }));

  static Future<Map<String, dynamic>> updatePropertyStatus(
    String id, {
    required String status,
  }) async =>
      _data(await _client().patchJson('/admin/properties/$id/status', body: {
        'status': status,
      }));
  static String formatCurrency(dynamic amount) {
    final value =
        amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0;
    return 'KSh ${value.toStringAsFixed(0)}';
  }

  static Future<Map<String, dynamic>> fetchSettings() async =>
      _data(await _client().getJson('/admin/settings'));

  static Future<void> updateSetting(
    String key,
    Map<String, dynamic> value,
  ) async {
    await _client().putJson('/admin/settings/$key', body: value);
  }
}
