import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

class UserService {
  static String get _baseUrl => '${AppSession.apiBaseUrl}/users';

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> changePassword(
      String current, String newPwd) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode({'currentPassword': current, 'newPassword': newPwd}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Network error'};
    }
  }
}
