import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:property_app/screens/home/cache_engine.dart';
import 'package:property_app/session/app_session.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic responseBody;

  ApiException(this.statusCode, this.message, {this.responseBody});

  String get userMessage {
    if (statusCode == 401) return 'Your session expired. Please log in again.';
    if (statusCode == 403) return 'You do not have permission to do that.';
    if (statusCode == 404) return 'The requested information was not found.';
    if (statusCode == 409)
      return 'This request conflicts with the current state.';
    if (statusCode == 422 || statusCode == 400) {
      return 'Please check the information and try again.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (statusCode >= 500) {
      return 'The service is temporarily unavailable. Please try again.';
    }
    return 'The request could not be completed. Please try again.';
  }

  @override
  String toString() => userMessage;
}

class ApiClient {
  final String baseUrl;
  final Map<String, String>? defaultHeaders;
  final Duration timeout;

  ApiClient({
    required this.baseUrl,
    this.defaultHeaders,
    this.timeout = const Duration(seconds: 30),
  });

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      ...?defaultHeaders,
    };
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(path, queryParams: queryParams);
    final ttl = CacheEngine.requestTtl(uri);
    if (ttl == null) {
      final response = await http.get(uri, headers: _headers).timeout(timeout);
      return _decodeResponse(response);
    }

    return CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
      key: CacheEngine.requestKey(
        uri,
        userId: AppSession.currentUserId,
        role: AppSession.currentRole,
      ),
      ttl: ttl,
      networkFetcher: () async {
        final response =
            await http.get(uri, headers: _headers).timeout(timeout);
        return _decodeResponse(response);
      },
    );
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .post(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    final decoded = _decodeResponse(response);
    await _invalidateAfterWrite(_buildUri(path));
    return decoded;
  }

  Future<Map<String, dynamic>> patchJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .patch(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    final decoded = _decodeResponse(response);
    await _invalidateAfterWrite(_buildUri(path));
    return decoded;
  }

  Future<Map<String, dynamic>> putJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .put(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    final decoded = _decodeResponse(response);
    await _invalidateAfterWrite(_buildUri(path));
    return decoded;
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = _buildUri(path);
    final response = await http.delete(uri, headers: _headers).timeout(timeout);

    final decoded = _decodeResponse(response);
    await _invalidateAfterWrite(_buildUri(path));
    return decoded;
  }

  Future<void> _invalidateAfterWrite(Uri uri) {
    return CacheEngine.instance.invalidateAfterWrite(
      uri: uri,
      userId: AppSession.currentUserId,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'data': decoded};
      } catch (err) {
        throw ApiException(
          response.statusCode,
          'Failed to decode API response.',
          responseBody: response.body,
        );
      }
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    final errorMessage = body is Map<String, dynamic> && body['message'] != null
        ? body['message'].toString()
        : 'Request failed with status ${response.statusCode}.';

    throw ApiException(
      response.statusCode,
      errorMessage,
      responseBody: body,
    );
  }
}
