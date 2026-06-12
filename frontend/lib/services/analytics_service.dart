import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';
import 'package:uuid/uuid.dart';

class AnalyticsService {
  // Matches backend `getTimeWindow` filter values
  static String mapAnalyticsFilter(String filter) {
    if (filter == 'Last 28 Days') return 'Last 28 Days';
    return 'This Week';
  }

  static Future<void> logEvent({

    required String eventType,
    String? propertyId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final url = Uri.parse('${AppSession.apiBaseUrl}/analytics/track');
      final response = await http.post(
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
          'sessionId': const Uuid().v4(),
          'metadata': metadata ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          print(
              'Analytics request failed: ${response.statusCode} ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log analytics event: $e');
      }
    }
  }
}
