import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/auth_service.dart'; // Import AuthService
import 'package:property_app/services/message_service.dart';

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

    // ── Step 1: Register FCM listeners FIRST ─────────────────────────────────
    // Isolated so a flutter_local_notifications failure never blocks delivery.
    try {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] authorization=${settings.authorizationStatus}');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            '[FCM] onMessage id=${message.messageId} title=${message.notification?.title} data=${message.data}');
        _notificationsController.add(message);
        try {
          _showLocalNotification(message);
        } catch (error, stackTrace) {
          debugPrint('[FCM] local notification failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        _showIncomingModal(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageAction);

      final RemoteMessage? initialMessage =
          await _messaging.getInitialMessage();
      if (initialMessage != null) _handleMessageAction(initialMessage);

      _messaging.onTokenRefresh.listen((newToken) {
        AuthService.instance.syncFCMToken(newToken: newToken);
      });

      final token = await getToken();
      debugPrint('[FCM] token=${(token?.length ?? 0) > 20 ? token!.substring(0, 20) : token ?? "null"}...');
    } catch (error, stackTrace) {
      debugPrint('[FCM] listener registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    // ── Step 2: Set up local notifications (foreground banners) ──────────────
    // Separate try/catch — a failure here never kills the listeners above.
    try {
      // ic_launcher_foreground is monochrome (required on Android 5+)
      const androidInit = AndroidInitializationSettings(
        'ic_launcher_foreground',
      );
      const iosInit = DarwinInitializationSettings();

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(_channel);
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('[FCM] Android notification permission=$granted');
      }

      debugPrint('[FCM] local notifications initialised');
    } catch (error, stackTrace) {
      debugPrint('[FCM] local notifications setup failed: $error');
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

    debugPrint(
        '[FCM] showing local notification id=${notification.hashCode} channel=${_channel.id}');
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
          icon: 'ic_launcher_foreground',
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
