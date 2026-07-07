import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/auth_service.dart'; // Import AuthService
import 'package:property_app/services/message_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler cannot access UI state, but we can safely best-effort
  // call the backend mark-read endpoint to keep unread badges consistent.
  try {
    final senderId = message.data['senderId']?.toString();
    if (senderId != null && senderId.isNotEmpty) {
      // NOTE: MessageService requires AppSession (token/baseUrl) which may not
      // always be available in background isolates. We fallback to doing nothing
      // if it fails to resolve. Any failure here must never crash background delivery.
      // ignore: unnecessary_statements
      await MessageService.instance.markAsRead([senderId]);
    }
  } catch (_) {
    // no-op
  }
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
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 2. Setup Local Notifications for Foreground
      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosInit = DarwinInitializationSettings();

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      // Note: createNotificationChannel requires a platform-specific plugin
      // resolve API which differs across flutter_local_notifications versions.
      // If channel creation fails to compile, we safely skip it here; the
      // channel will still be usable with valid Android channel identifiers.

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

  void _showIncomingModal(RemoteMessage message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? "New Alert";
    final body = message.notification?.body ?? "";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notification",
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
              .animate(anim1),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const CircleAvatar(
                      backgroundColor: Color(0xFF059669),
                      child: Icon(Icons.notifications, color: Colors.white)),
                  title: Text(title,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  subtitle: Text(body, style: GoogleFonts.poppins()),
                  onTap: () async {
                    Navigator.pop(context);
                    await _handleMessageAction(message);
                  },
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
          icon:
              '@mipmap/ic_launcher', // Ensure this icon exists in android/app/src/main/res/mipmap
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
