import 'dart:convert';
import 'package:property_app/repository/http_json_client.dart';
import 'package:property_app/session/app_session.dart';

class VerificationApi {
  static final HttpJsonClient _client = HttpJsonClient();

  /// Submit verification payload. `payload` should contain `documents` and optional `property`.
  static Future<Map<String, dynamic>> submitVerification(
      Map<String, dynamic> payload, {String? idempotencyKey}) async {
    final headers = idempotencyKey != null ? {'Idempotency-Key': idempotencyKey} : <String, String>{};
    final response = await _client.post(
      Uri.parse('${AppSession.apiBaseUrl}/verifications'),
      headers: headers,
      body: payload,
    );
    final data = jsonDecode(response.body);
    return data['data'] as Map<String, dynamic>;
  }

  /// Fetch the current user's latest verification status.
  ///
  /// Expected backend shape:
  ///   { data: { status, documents, property_data, admin_notes, ... } }
  /// Some client code may receive an extra nesting depending on API wrappers.
  static Future<Map<String, dynamic>?> getVerificationStatus() async {
    final response = await _client.get(Uri.parse('${AppSession.apiBaseUrl}/verifications/me'));
    final decoded = jsonDecode(response.body);

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      // Normal case: data contains `status` directly
      if (data['status'] != null) return data;

      // Compatibility: data might be nested under another `data`
      final nested = data['data'];
      if (nested is Map<String, dynamic> && nested['status'] != null) {
        return nested;
      }
    }

    return null;
  }

  /// Fetch all verifications for admin dashboard (paginated).
  static Future<Map<String, dynamic>> getAdminVerifications({
    String? status,
    int offset = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    params['offset'] = offset.toString();
    params['limit'] = limit.toString();

    final response = await _client.get(
      Uri.parse('${AppSession.apiBaseUrl}/verifications/admin/all').replace(queryParameters: params),
    );
    final decoded = jsonDecode(response.body);

    return {
      'data': decoded['data'] as List<dynamic>? ?? [],
      'total': decoded['total'] as int? ?? 0,
      'offset': decoded['offset'] as int? ?? offset,
      'limit': decoded['limit'] as int? ?? limit,
    };
  }

  /// Fetch pending verifications only.
  static Future<List<Map<String, dynamic>>> getPendingVerifications({
    int limit = 10,
  }) async {
    final result = await getAdminVerifications(
      status: 'submitted',
      limit: limit,
    );
    return (result['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Approve a verification.
  static Future<Map<String, dynamic>> approveVerification({
    required String verificationId,
    String? notes,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppSession.apiBaseUrl}/verifications/$verificationId'),
      body: {
        'status': 'approved',
        'admin_notes': notes,
      },
    );
    return jsonDecode(response.body)['data'] as Map<String, dynamic>;
  }

  /// Reject a verification.
  static Future<Map<String, dynamic>> rejectVerification({
    required String verificationId,
    String? notes,
  }) async {
    final response = await _client.patch(
      Uri.parse('${AppSession.apiBaseUrl}/verifications/$verificationId'),
      body: {
        'status': 'rejected',
        'admin_notes': notes,
      },
    );
    return jsonDecode(response.body)['data'] as Map<String, dynamic>;
  }
}
