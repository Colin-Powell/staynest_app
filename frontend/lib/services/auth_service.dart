import 'dart:convert';

import 'package:property_app/services/fcm_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:flutter/foundation.dart';
import 'package:property_app/repository/http_json_client.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final HttpJsonClient _client = HttpJsonClient();

  /// Call this immediately after a successful login or during app bootstrap
  /// [newToken] can be provided if the token has just refreshed.
  Future<void> syncFCMToken(
      {String? newToken, bool? notificationsAllowed}) async {
    if (kIsWeb) return;

    final userId = AppSession.currentUserId;
    final fcmToken = newToken ?? await FCMService.instance.getToken();

    if (fcmToken == null || userId == null) return;

    try {
      bool? permission = notificationsAllowed;
      if (permission == null) {
        try {
          final settings =
              await FirebaseMessaging.instance.getNotificationSettings();
          permission = settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
        } catch (_) {
          // Leave server state unchanged if the platform cannot report it yet.
        }
      }
      // Using PUT as per production standards for updating resource state
      await _client.put(
        Uri.parse('${AppSession.apiBaseUrl}/users/$userId/fcm-token'),
        body: {
          'fcmToken': fcmToken,
          if (permission != null) 'notificationsAllowed': permission,
        },
      );

      debugPrint('FCM Token synced successfully');
    } catch (e) {
      debugPrint('Failed to sync FCM token to backend: $e');
    }
  }

  Future<void> updateNotificationSettings(Map<String, dynamic> settings) async {
    if (AppSession.currentUserId == null) return;
    await _client.patch(
      Uri.parse('${AppSession.apiBaseUrl}/users/profile'),
      body: {'settings': settings},
    );
  }

  Future<Map<String, dynamic>> fetchNotificationSettings() async {
    final response = await _client.get(
      Uri.parse('${AppSession.apiBaseUrl}/users/me'),
      bypassCache: true,
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! Map) return {};
    final settings = (decoded['data'] as Map)['settings'];
    return settings is Map ? Map<String, dynamic>.from(settings) : {};
  }

  Future<void> clearFCMToken() async {
    final userId = AppSession.currentUserId;
    if (userId == null) return;
    try {
      await _client.delete(
        Uri.parse('${AppSession.apiBaseUrl}/users/$userId/fcm-token'),
      );
    } catch (error) {
      debugPrint('Failed to remove FCM token during logout: $error');
    }
  }
}
