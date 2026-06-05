import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic responseBody;

  ApiException(this.statusCode, this.message, {this.responseBody});

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, responseBody: $responseBody)';
  }
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
    final response = await http.get(uri, headers: _headers).timeout(timeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .post(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> patchJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .patch(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> putJson(String path,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(path);
    final response = await http
        .put(uri,
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(timeout);

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = _buildUri(path);
    final response = await http.delete(uri, headers: _headers).timeout(timeout);

    return _decodeResponse(response);
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
