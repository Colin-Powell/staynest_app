import 'package:property_app/services/api_client.dart';
import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';

class UserService {
  static final HttpJsonClient _client = HttpJsonClient();
  static String get _baseUrl => '${AppSession.apiBaseUrl}/users';

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      await _client.patch(
        Uri.parse('$_baseUrl/profile'),
        body: data,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> changePassword(
      String current, String newPwd) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/change-password'),
        body: {'currentPassword': current, 'newPassword': newPwd},
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Network error'};
    }
  }
}
