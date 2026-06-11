import 'package:property_app/services/fcm_service.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  /// Call this immediately after a successful login or during app bootstrap
  /// [newToken] can be provided if the token has just refreshed.
  Future<void> syncFCMToken({String? newToken}) async {
    final userId = AppSession.currentUserId;
    final fcmToken = newToken ?? await FCMService.instance.getToken();

    if (fcmToken == null || userId == null) return;

    try {
      // Using PUT as per production standards for updating resource state
      final response = await http.put(
        Uri.parse('${AppSession.apiBaseUrl}/users/$userId/fcm-token'),
        body: {'fcmToken': fcmToken},
        headers: {
          'Authorization': 'Bearer ${AppSession.authToken}',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('FCM Token synced successfully');
      }
    } catch (e) {
      debugPrint('Failed to sync FCM token to backend: $e');
    }
  }
}
