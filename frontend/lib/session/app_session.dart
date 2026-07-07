import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:property_app/screens/home/cache_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const String _prefsKey = 'staynest.session';

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
  static String? refreshToken;

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

  /// Cloudinary configuration for image assets
  static const String cloudinaryCloudName = 'dxcht5cls';
  static const String cloudinaryBaseUrl =
      'https://res.cloudinary.com/$cloudinaryCloudName/image/upload';

  /// Resolves any avatar path or Cloudinary ID into a usable [ImageProvider].
  /// Handles full URLs, local asset paths, and relative server upload IDs.
  static ImageProvider getAvatarProvider(String? path) {
    final avatar = (path?.trim().isNotEmpty == true)
        ? path!.trim()
        : 'assets/images/profile.jpg';

    if (avatar.startsWith('http')) {
      return NetworkImage(avatar);
    }
    if (avatar.startsWith('assets/')) {
      return AssetImage(avatar);
    }

    // Resolve Cloudinary IDs (e.g., 'staynest/filename')
    // We append .jpg extension if missing to ensure proper network resource resolution
    final fullId = avatar.contains('.') ? avatar : '$avatar.jpg';
    return NetworkImage('$cloudinaryBaseUrl/$fullId');
  }

  /// Returns the [ImageProvider] for the currently authenticated user's avatar.
  static ImageProvider get currentUserAvatarProvider =>
      getAvatarProvider(currentUserAvatar);

  /// Builds a [Widget] for displaying an avatar with a shimmer loading effect.
  static Widget buildAvatar(String? path,
      {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final avatar = (path?.trim().isNotEmpty == true) ? path!.trim() : '';
    final hasRealAvatar =
        avatar.isNotEmpty && !avatar.startsWith('assets/images/profile.jpg');

    if (!hasRealAvatar) {
      return Image.asset(
        'assets/images/profile.jpg',
        width: width,
        height: height,
        fit: fit,
      );
    }

    if (avatar.startsWith('assets/')) {
      return Image.asset(avatar, width: width, height: height, fit: fit);
    }

    final url = avatar.startsWith('http')
        ? avatar
        : '$cloudinaryBaseUrl/${avatar.contains('.') ? avatar : '$avatar.jpg'}';

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width != null ? (width * 2).toInt() : null,
      cacheHeight: height != null ? (height * 2).toInt() : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const _ShimmerPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/profile.jpg',
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  static String get displayRole {
    final role = currentRole.trim();
    if (role.isEmpty) return 'Tenant';
    return '${role[0].toUpperCase()}${role.substring(1)}';
  }

  static Map<String, dynamic> toSessionSnapshot() => {
        'user': {
          'id': currentUserId,
          'name': currentUserName,
          'email': currentUserEmail,
          'phone': currentUserPhone,
          'avatar': currentUserAvatar,
          'role': currentRole,
          'verified': currentUserVerified,
        },
        'tokens': {
          'apiToken': apiToken,
          'refreshToken': refreshToken,
        },
      };

  static Future<void> persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toSessionSnapshot()));
  }

  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(_prefsKey);
        return;
      }

      final user = decoded['user'];
      final tokens = decoded['tokens'];
      if (user is Map) {
        updateCurrentUser(Map<String, dynamic>.from(user as Map));
      }
      if (tokens is Map) {
        apiToken = tokens['apiToken']?.toString();
        refreshToken = tokens['refreshToken']?.toString();
      }
    } catch (_) {
      await prefs.remove(_prefsKey);
    }
  }

  static Future<void> clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static void applySessionSnapshot(Map<String, dynamic> snapshot) {
    final user = snapshot['user'];
    final tokens = snapshot['tokens'];
    if (user is Map) {
      updateCurrentUser(Map<String, dynamic>.from(user));
    }
    if (tokens is Map) {
      apiToken = tokens['apiToken']?.toString();
      refreshToken = tokens['refreshToken']?.toString();
    }
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

  static Future<void> reset() async {
    currentRole = 'tenant';
    currentUserId = null;
    currentUserName = null;
    currentUserEmail = null;
    currentUserPhone = null;
    currentUserAvatar = null;
    currentUserVerified = false;
    apiToken = null;
    refreshToken = null;
    await clearPersistedSession();
    await CacheEngine.instance
        .clearAll(); // Critical: Invalidate cache on logout
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder();

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        color: Colors.grey[300],
      ),
    );
  }
}
