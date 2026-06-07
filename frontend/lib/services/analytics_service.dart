import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

class AnalyticsService {
  static Future<void> logEvent({
    required String eventType,
    String? propertyId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final url = Uri.parse('${AppSession.apiBaseUrl}/analytics/events');

      http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (AppSession.apiToken != null)
            'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode({
          'eventType': eventType,
          'userId': AppSession.currentUserId,
          'propertyId': propertyId,
          'metadata': metadata ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).catchError((e) {
        if (kDebugMode) {
          print('Analytics error: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log analytics event: $e');
      }
    }
  }
}  