import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal JSON HTTP client used by repositories.
class HttpJsonClient {
  final http.Client _client;

  HttpJsonClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _client.get(uri, headers: headers);
  }

  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client.post(
      uri,
      headers: headers,
      body: body is String ? body : body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _client.patch(
      uri,
      headers: headers,
      body: body is String ? body : body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _client.delete(uri, headers: headers);
  }
}

