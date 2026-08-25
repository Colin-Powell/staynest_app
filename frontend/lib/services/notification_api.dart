import 'dart:convert';
import 'package:property_app/repository/http_json_client.dart';
import 'package:property_app/session/app_session.dart';

class NotificationApi {
  static final HttpJsonClient _client = HttpJsonClient();

  static Future<Map<String, dynamic>> fetchNotifications({int limit = 50, int offset = 0}) async {
    final response = await _client.get(
      Uri.parse('${AppSession.apiBaseUrl}/notifications?limit=$limit&offset=$offset'),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _client.put(
      Uri.parse('${AppSession.apiBaseUrl}/notifications/$notificationId/read'),
    );
  }

  static Future<void> markAllAsRead() async {
    await _client.put(
      Uri.parse('${AppSession.apiBaseUrl}/notifications/read-all'),
    );
  }
}