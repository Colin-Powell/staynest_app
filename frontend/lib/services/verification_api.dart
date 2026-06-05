import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

class VerificationApi {
  static ApiClient _client() {
    return ApiClient(
      baseUrl: AppSession.apiBaseUrl,
      defaultHeaders: AppSession.apiToken != null
          ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
          : null,
    );
  }

  /// Submit verification payload. `payload` should contain `documents` and optional `property`.
  static Future<Map<String, dynamic>> submitVerification(
      Map<String, dynamic> payload) async {
    final client = _client();
    final response = await client.postJson('/verifications', body: payload);
    return response['data'] as Map<String, dynamic>;
  }

  /// Fetch the current user's latest verification status.
  ///
  /// Expected backend shape:
  ///   { data: { status, documents, property_data, admin_notes, ... } }
  /// Some client code may receive an extra nesting depending on API wrappers.
  static Future<Map<String, dynamic>?> getVerificationStatus() async {
    final client = _client();
    final response = await client.getJson('/verifications/me');

    final data = response['data'];
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
    final client = _client();
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    params['offset'] = offset.toString();
    params['limit'] = limit.toString();

    final response = await client.getJson(
      '/verifications/admin/all',
      queryParams: params,
    );

    return {
      'data': response['data'] as List<dynamic>? ?? [],
      'total': response['total'] as int? ?? 0,
      'offset': response['offset'] as int? ?? offset,
      'limit': response['limit'] as int? ?? limit,
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
    final client = _client();
    final response = await client.putJson(
      '/verifications/$verificationId',
      body: {
        'status': 'approved',
        'admin_notes': notes,
      },
    );
    return response['data'] as Map<String, dynamic>;
  }

  /// Reject a verification.
  static Future<Map<String, dynamic>> rejectVerification({
    required String verificationId,
    String? notes,
  }) async {
    final client = _client();
    final response = await client.putJson(
      '/verifications/$verificationId',
      body: {
        'status': 'rejected',
        'admin_notes': notes,
      },
    );
    return response['data'] as Map<String, dynamic>;
  }
}
