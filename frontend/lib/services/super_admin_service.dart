import 'dart:convert';

import 'package:property_app/repository/http_json_client.dart';
import 'package:property_app/session/app_session.dart';

class SuperAdminService {
  static final HttpJsonClient _client = HttpJsonClient();

  static Uri _uri(String path) => Uri.parse(
      '${AppSession.apiBaseUrl.replaceFirst(RegExp(r'/$'), '')}$path');

  static Future<Map<String, dynamic>> _getJson(String path,
      {Map<String, String>? query}) async {
    final uri = _uri(path).replace(queryParameters: query);
    final response = await _client.get(uri);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _decode(
      Future<dynamic> Function() request) async {
    final response = await request();
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

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
      _data(await _getJson('/admin/overview'));

  static Future<List<Map<String, dynamic>>> fetchUsers({
    int limit = 10,
    int offset = 0,
    String? search,
    String? role,
  }) async =>
      _list(await _getJson('/admin/users', query: {
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
      _list(await _getJson('/admin/properties', query: {
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
      _list(await _getJson('/admin/kyc', query: {
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
      _data(await _decode(() => _client.patch(_uri('/admin/kyc/$id'), body: {
            'status': status,
            if (adminNotes != null) 'admin_notes': adminNotes,
          })));

  static Future<Map<String, dynamic>> updatePropertyStatus(
    String id, {
    required String status,
  }) async =>
      _data(await _decode(
          () => _client.patch(_uri('/admin/properties/$id/status'), body: {
                'status': status,
              })));
  static String formatCurrency(dynamic amount) {
    final value =
        amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0;
    return 'KSh ${value.toStringAsFixed(0)}';
  }

  static Future<Map<String, dynamic>> fetchSettings() async =>
      _data(await _getJson('/admin/settings'));

  static Future<void> updateSetting(
    String key,
    Map<String, dynamic> value,
  ) async {
    await _client.put(_uri('/admin/settings/$key'), body: value);
  }
}
