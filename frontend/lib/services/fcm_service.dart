import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/auth_service.dart'; // Import AuthService
import 'package:property_app/services/message_service.dart';
import 'package:property_app/theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep this handler lightweight. Android displays notification payloads in
  // the background; read state changes only when the user opens the chat.
}

class FCMService {
  static final FCMService instance = FCMService._();
  FCMService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<RemoteMessage> _notificationsController =
      StreamController<RemoteMessage>.broadcast();

  Stream<RemoteMessage> get notificationsStream =>
      _notificationsController.stream;

  // Define the Android Notification Channel for high importance
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  // Global key or Navigator state to show modals
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      debugPrint(
          '[FCM] skipped because Firebase is unavailable on this platform.');
      return;
    }

    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Set iOS foreground presentation options
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 1. Request Permissions (iOS/Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] authorization=${settings.authorizationStatus}');

      // 2. Setup Local Notifications for Foreground
      const androidInit = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );

      const iosInit = DarwinInitializationSettings();

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      // Create Android Notification Channel
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(_channel);
      }

      // 3. Handle Foreground Messages & Trigger Modal
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _notificationsController.add(message);
        _showLocalNotification(message);
        _showIncomingModal(message);
      });

      // 4. Handle Notification Clicks (App in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageAction);

      // 5. Handle App start from terminated state
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _handleMessageAction(initialMessage);

      // 6. Token Refresh
      _messaging.onTokenRefresh.listen((newToken) {
        AuthService.instance
            .syncFCMToken(newToken: newToken); // Sync new token to backend
      });

      // Print token for testing purposes
      final token = await getToken();
      debugPrint("FCM Token: $token");
    } catch (error, stackTrace) {
      debugPrint('[FCM] initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> getToken() async {
    return FCMService.runWithFallback<String?>(
      action: () async => _messaging.getToken(),
      label: 'FCM token',
      fallback: null,
    );
  }

  static Future<T?> runWithFallback<T>({
    required Future<T> Function() action,
    required String label,
    T? fallback,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      debugPrint('[$label] failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return fallback;
    }
  }

  bool _isNavigatingFromNotification = false;

  Future<void> _handleMessageAction(RemoteMessage message) async {
    if (_isNavigatingFromNotification) return;
    _isNavigatingFromNotification = true;

    try {
      final chatId = message.data['chatId'];
      final senderId = message.data['senderId']?.toString();

      // State action: mark messages from sender as read for the current user.
      // (Chat open will also mark read, but this ensures unread badges update sooner.)
      if (senderId != null && senderId.isNotEmpty) {
        await MessageService.instance.markAsRead([senderId]);
      }

      if (chatId != null && navigatorKey != null) {
        // Navigate to chat and ensure background stack is consistent
        navigatorKey!.currentState?.pushNamed(
          '/chat',
          arguments: {
            'userId': senderId,
            'name': message.notification?.title ?? 'User',
            'chatId': chatId,
            'avatar': message.data['avatar'] ?? '',
          },
        );
      }
    } finally {
      // small delay to avoid rapid double taps from double deliveries
      await Future<void>.delayed(const Duration(milliseconds: 150));
      _isNavigatingFromNotification = false;
    }
  }

  IconData _notificationIcon(RemoteMessage message) {
    final type = message.data['type']?.toString().toLowerCase() ?? '';
    if (type.contains('message') || type.contains('unread')) {
      return PhosphorIconsRegular.chatCircleText;
    }
    if (type.contains('booking') ||
        type.contains('checkin') ||
        type.contains('checkout')) {
      return PhosphorIconsRegular.calendarCheck;
    }
    if (type.contains('payment') || type.contains('price')) {
      return PhosphorIconsRegular.wallet;
    }
    if (type.contains('alert') ||
        type.contains('warning') ||
        type.contains('stale')) {
      return PhosphorIconsRegular.warning;
    }
    if (type.contains('approved') || type.contains('success')) {
      return PhosphorIconsRegular.checkCircle;
    }
    return PhosphorIconsRegular.bell;
  }

  Color _notificationAccent(RemoteMessage message) {
    final type = message.data['type']?.toString().toLowerCase() ?? '';
    if (type.contains('message') || type.contains('unread')) {
      return StayNestColors.primary;
    }
    if (type.contains('booking') ||
        type.contains('checkin') ||
        type.contains('checkout')) {
      return StayNestColors.info;
    }
    if (type.contains('payment') || type.contains('price')) {
      return StayNestColors.accentDark;
    }
    if (type.contains('alert') ||
        type.contains('warning') ||
        type.contains('stale')) {
      return StayNestColors.warning;
    }
    if (type.contains('approved') || type.contains('success')) {
      return StayNestColors.success;
    }
    return StayNestColors.primary;
  }

  void _showIncomingModal(RemoteMessage message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'New update';
    final body = message.notification?.body ?? '';
    final accent = _notificationAccent(message);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          )),
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.cardBorderRadius,
                    onTap: () async {
                      Navigator.pop(context);
                      await _handleMessageAction(message);
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: StayNestColors.surfaceLight,
                        borderRadius: AppRadius.cardBorderRadius,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.18),
                        ),
                        boxShadow: AppShadow.lg,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _notificationIcon(message),
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'StayNest',
                                        style: GoogleFonts.poppins(
                                          color: accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      PhosphorIconsRegular.arrowUpRight,
                                      color: StayNestColors.textMutedLight,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: StayNestColors.textPrimaryLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: StayNestColors.textSecondaryLight,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLocalNotification(RemoteMessage message) {
    final RemoteNotification? notification = message.notification;

    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: _channel.importance,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: message.data['chatId']?.toString(),
    );
  }

  /// Subscribe to a topic (e.g., 'announcements' or 'city_london')
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
