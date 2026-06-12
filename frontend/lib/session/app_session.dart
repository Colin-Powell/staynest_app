import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:property_app/screens/home/cache_engine.dart';

class AppSession {
  static String currentRole = 'tenant';
  static final ValueNotifier<String> currentRoleNotifier =
      ValueNotifier(currentRole);
  static Map<String, dynamic> get currentUser => <String, dynamic>{
        'id': currentUserId,
        'name': currentUserName,
        'email': currentUserEmail,
        'phone': currentUserPhone,
        'avatar': currentUserAvatar,
        'role': currentRole,
        'verified': currentUserVerified,
      };

  /// Backward-compatible logout used by older UI code.
  static void logout() {
    reset();
  }

  static void setRole(String role) {
    currentRole = role;
    currentRoleNotifier.value = role;
  }

  static String? currentUserId;
  static String? currentUserName;
  static String? currentUserEmail;
  static String? currentUserPhone;
  static String? currentUserAvatar;
  static bool currentUserVerified = false;
  // For Android emulators use 10.0.2.2 to reach the host machine.
  // For physical Android devices, use one of these:
  // 1) USB + adb reverse:
  //    adb reverse tcp:8080 tcp:8080
  //    API_BASE_URL=http://127.0.0.1:8080/api
  // 2) Same Wi-Fi network:
  //    API_BASE_URL=http://<YOUR_PC_IP>:8080/api
  // If the app still fails with Connection refused, adb reverse is not active or the device cannot reach your host.
  static String get apiBaseUrl {
    final envUrl = dotenv.env['API_BASE_URL']?.trim();
    if (envUrl?.isNotEmpty == true) {
      return envUrl!;
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8080/api',
    );
  }

  static String? apiToken;

  // Backward-compatible alias (some code references authToken).
  static String? get authToken => apiToken;

  static final Set<String> savedPropertyIds = {};

  static bool isSaved(String id) => savedPropertyIds.contains(id);

  static void setSavedPropertyIds(Iterable<String> ids) {
    savedPropertyIds
      ..clear()
      ..addAll(ids);
  }

  static void toggleSaved(String id) {
    if (savedPropertyIds.contains(id)) {
      savedPropertyIds.remove(id);
    } else {
      savedPropertyIds.add(id);
      AnalyticsService.trackPropertySave(id);
    }
  }

  static void trackEngagement(String eventType, String propertyId) {
    // This allows tracking clicks, views, etc.
    AnalyticsService.logEvent(eventType: eventType, propertyId: propertyId);
  }

  static String get displayName => currentUserName?.trim().isNotEmpty == true
      ? currentUserName!.trim()
      : 'Guest';

  static String get displayEmail => currentUserEmail?.trim().isNotEmpty == true
      ? currentUserEmail!.trim()
      : 'guest@example.com';

  static String get displayPhone => currentUserPhone?.trim().isNotEmpty == true
      ? currentUserPhone!.trim()
      : '';

  static String get displayAvatar =>
      currentUserAvatar?.trim().isNotEmpty == true
          ? currentUserAvatar!.trim()
          : 'assets/images/profile.jpg';

  static String get displayRole {
    final role = currentRole.trim();
    if (role.isEmpty) return 'Tenant';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  static void updateCurrentUser(Map<String, dynamic> user) {
    currentUserId = user['id']?.toString();
    currentUserName = user['name']?.toString();
    currentUserEmail = user['email']?.toString();
    currentUserPhone = user['phone']?.toString();
    currentUserAvatar = user['avatar']?.toString();
    currentRole = user['role']?.toString() ?? currentRole;
    currentUserVerified = user['verified'] == true;
  }

  static bool get isLandlord =>
      currentRole == 'landlord' || currentRole == 'host';

  static void reset() {
    currentRole = 'tenant';
    currentUserId = null;
    currentUserName = null;
    currentUserEmail = null;
    currentUserPhone = null;
    currentUserAvatar = null;
    currentUserVerified = false;
    apiToken = null;
    CacheEngine.instance.clearAll(); // Critical: Invalidate cache on logout
  }
}
