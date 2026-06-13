import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

import '../services/api_client.dart'; // ApiException

// Note: this file intentionally uses a small, repository-friendly HTTP wrapper.
// It is responsible for access-token attachment, refresh-on-401, and retry-once.

/// Minimal JSON HTTP client used by repositories.
///
/// Responsibilities:
/// - Attach access token automatically
/// - Detect 401 responses
/// - Refresh access token (one in-flight refresh at a time)
/// - Retry the original request once after refresh
class HttpJsonClient {
  final http.Client _client;
  final Duration timeout;

  HttpJsonClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  // Ensures only one refresh request runs at a time.
  static Future<void>? _refreshing;

  // ApiException used for missing refresh token fallback.

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (AppSession.apiToken != null)
          'Authorization': 'Bearer ${AppSession.apiToken}',
      };

  Future<void> _refreshAccessTokenIfPossible() async {
    if (_refreshing != null) {
      await _refreshing;
      return;
    }

    // If the app doesn't have a refresh token, can't refresh.
    if (AppSession.refreshToken == null) {
      throw ApiException(401, 'Missing refresh token');
    }

    _refreshing = () async {
      final refreshToken = AppSession.refreshToken!;
      final response = await _client.post(
        Uri.parse('${AppSession.apiBaseUrl}/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(response.statusCode, 'Token refresh failed');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];

      // Expected backend shape: { data: { accessToken, refreshToken? , user? } }
      if (data is Map<String, dynamic>) {
        final newAccess = data['accessToken']?.toString();
        final newRefresh = data['refreshToken']?.toString();
        if (newAccess != null && newAccess.isNotEmpty) {
          AppSession.apiToken = newAccess;
        }
        if (newRefresh != null && newRefresh.isNotEmpty) {
          AppSession.refreshToken = newRefresh;
        }
        return;
      }

      // Some backends may return tokens at root.
      final newAccessRoot = decoded['accessToken']?.toString();
      final newRefreshRoot = decoded['refreshToken']?.toString();
      if (newAccessRoot != null && newAccessRoot.isNotEmpty) {
        AppSession.apiToken = newAccessRoot;
      }
      if (newRefreshRoot != null && newRefreshRoot.isNotEmpty) {
        AppSession.refreshToken = newRefreshRoot;
      }
    }();

    try {
      await _refreshing;
    } finally {
      _refreshing = null;
    }
  }

  /// Creates an ApiException from an http.Response.
  ApiException _toApiException(http.Response response) {
    String message = 'Request failed with status ${response.statusCode}';
    dynamic body;
    try {
      body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}

    return ApiException(response.statusCode, message, responseBody: body);
  }

  Future<http.Response> _sendWithOptionalRetry(
    Future<http.Response> Function() send,
  ) async {
    final first = await send().timeout(timeout);

    if (kDebugMode) {
      debugPrint(
        '[HTTP] ${first.request?.method} ${first.request?.url} -> ${first.statusCode}',
      );
    }

    if (first.statusCode >= 200 && first.statusCode < 300) return first;

    // Retry-once logic for 401.
    if (first.statusCode == 401) {
      await _refreshAccessTokenIfPossible();
      final second = await send().timeout(timeout);
      if (second.statusCode >= 200 && second.statusCode < 300) return second;
      throw _toApiException(second);
    }

    throw _toApiException(first);
  }

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _sendWithOptionalRetry(() async {
      return _client.get(uri, headers: {..._authHeaders, ...?headers});
    });
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final encodedBody =
        body is String ? body : (body == null ? null : jsonEncode(body));
    return _sendWithOptionalRetry(() async {
      return _client.post(
        uri,
        headers: {..._authHeaders, ...?headers},
        body: encodedBody,
      );
    });
  }

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    final encodedBody =
        body is String ? body : (body == null ? null : jsonEncode(body));
    return _sendWithOptionalRetry(() async {
      return _client.patch(
        uri,
        headers: {..._authHeaders, ...?headers},
        body: encodedBody,
      );
    });
  }

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _sendWithOptionalRetry(() async {
      return _client.delete(uri, headers: {..._authHeaders, ...?headers});
    });
  }
}
