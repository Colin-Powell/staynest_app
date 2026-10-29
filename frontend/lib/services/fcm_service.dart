import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/auth_service.dart'; // Import AuthService
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/notification_api.dart';
import 'package:property_app/theme.dart';
import 'package:property_app/utils/promotion_notification.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep this handler lightweight. Android displays notification payloads in
  // the background; read state changes only when the user opens the chat.
}

class FCMService with WidgetsBindingObserver {
  static final FCMService instance = FCMService._();
  FCMService._();

  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
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
  static const AndroidNotificationChannel _promotionChannel =
      AndroidNotificationChannel(
    'promotions',
    'Property promotions',
    description: 'Promotional updates about StayNest listings.',
    importance: Importance.high,
  );

  // Global key or Navigator state to show modals
  GlobalKey<NavigatorState>? navigatorKey;
  OverlayEntry? _incomingBannerEntry;
  Timer? _incomingBannerTimer;
  Future<void> Function(
    String? conversationId,
    String? senderId,
    String? name,
    String? avatar,
  )? onDesktopMessageAction;

  Future<void> initialize() async {
    if (kIsWeb || Firebase.apps.isEmpty) {
      debugPrint(
          '[FCM] skipped because Firebase is unavailable on this platform.');
      return;
    }
    if (!_lifecycleObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAdded = true;
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

      var settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      debugPrint('[FCM] authorization=${settings.authorizationStatus}');
      await _messaging.unsubscribeFromTopic('promotions');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
            '[FCM] onMessage id=${message.messageId} title=${message.notification?.title} data=${message.data}');
        _notificationsController.add(message);
        unawaited(_showLocalNotification(message));
        if (message.data['type']?.toString() != 'property_promotion') {
          _showIncomingModal(message);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageAction);

      final RemoteMessage? initialMessage =
          await _messaging.getInitialMessage();
      if (initialMessage != null) _handleMessageAction(initialMessage);

      _messaging.onTokenRefresh.listen((newToken) {
        AuthService.instance.syncFCMToken(newToken: newToken);
      });

      final token = await getToken();
      debugPrint(
          '[FCM] token=${(token?.length ?? 0) > 20 ? token!.substring(0, 20) : token ?? "null"}...');
      if (token != null) {
        unawaited(AuthService.instance.syncFCMToken(
          newToken: token,
          notificationsAllowed: settings.authorizationStatus ==
                  AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional,
        ));
      }
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
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final data = jsonDecode(payload);
            if (data is Map) {
              unawaited(_handleMessageAction(RemoteMessage(
                data: Map<String, dynamic>.from(data),
              )));
            }
          } catch (error) {
            debugPrint('[FCM] local notification payload was invalid: $error');
          }
        },
      );

      final androidImpl =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(_channel);
        await androidImpl.createNotificationChannel(_promotionChannel);
      }

      await _removeExpiredPromotionImages();
      debugPrint('[FCM] local notifications initialised');
    } catch (error, stackTrace) {
      debugPrint('[FCM] local notifications setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) return null;

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
  bool _lifecycleObserverAdded = false;

  Future<void> _handleMessageAction(RemoteMessage message) async {
    if (_isNavigatingFromNotification) return;
    _isNavigatingFromNotification = true;

    try {
      final chatId = message.data['chatId'];
      final senderId = message.data['senderId']?.toString();
      final conversationId = message.data['conversationId']?.toString();

      final propertyRoute = promotionPropertyRoute(message.data);
      if (propertyRoute != null) {
        final propertyId = message.data['propertyId']?.toString() ?? '';

        for (var attempt = 0;
            attempt < 50 && navigatorKey?.currentState == null;
            attempt += 1) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        final navigator = navigatorKey?.currentState;
        if (navigator == null) return;

        final campaignId = message.data['campaignId']?.toString() ?? '';
        if (promotionPropertyRoute({
              'type': 'property_promotion',
              'propertyId': campaignId,
            }) !=
            null) {
          unawaited(NotificationApi.trackPromotionOpen(
            campaignId: campaignId,
            propertyId: propertyId,
          ).catchError((error) {
            debugPrint('[FCM] campaign open tracking failed: $error');
          }));
        }
        navigator.pushNamed(propertyRoute);
        return;
      }

      if (conversationId != null && conversationId.isNotEmpty) {
        await MessageService.instance.markAsRead(
          const [],
          conversationIds: [conversationId],
        );
      } else if (senderId != null && senderId.isNotEmpty) {
        await MessageService.instance.markAsRead([senderId]);
      }

      final currentContext = navigatorKey?.currentContext;
      final isDesktop = currentContext != null &&
          currentContext.mounted &&
          MediaQuery.sizeOf(currentContext).width >= 768;
      if (isDesktop && onDesktopMessageAction != null) {
        await onDesktopMessageAction!(
          conversationId,
          senderId,
          message.notification?.title,
          message.data['avatar']?.toString(),
        );
        return;
      }

      if ((chatId != null || conversationId != null) && navigatorKey != null) {
        navigatorKey!.currentState?.pushNamed(
          conversationId == null || conversationId.isEmpty
              ? '/chat'
              : '/chat/$conversationId',
          arguments: {
            'userId': senderId,
            'name': message.notification?.title ?? 'User',
            'chatId': chatId,
            if (conversationId != null) 'conversationId': conversationId,
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncNotificationAuthorization());
    }
  }

  Future<void> _syncNotificationAuthorization() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    final token = await getToken();
    if (token == null) return;
    final settings = await _messaging.getNotificationSettings();
    await AuthService.instance.syncFCMToken(
      newToken: token,
      notificationsAllowed:
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional,
    );
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

    if (MediaQuery.sizeOf(context).width >= 768) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;

      _incomingBannerTimer?.cancel();
      if (_incomingBannerEntry?.mounted == true) {
        _incomingBannerEntry!.remove();
      }

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (_) => _buildIncomingBanner(
          message,
          onTap: () {
            _incomingBannerTimer?.cancel();
            if (entry.mounted) entry.remove();
            unawaited(_handleMessageAction(message));
          },
        ),
      );
      _incomingBannerEntry = entry;
      overlay.insert(entry);
      _incomingBannerTimer = Timer(const Duration(seconds: 6), () {
        if (entry.mounted) entry.remove();
        if (identical(_incomingBannerEntry, entry)) {
          _incomingBannerEntry = null;
          _incomingBannerTimer = null;
        }
      });
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notification',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      pageBuilder: (dialogContext, anim1, anim2) => _buildIncomingBanner(
        message,
        onTap: () {
          Navigator.of(dialogContext).pop();
          unawaited(_handleMessageAction(message));
        },
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildIncomingBanner(
    RemoteMessage message, {
    required VoidCallback onTap,
  }) {
    final title = message.notification?.title ?? 'New update';
    final body = message.notification?.body ?? '';
    final accent = _notificationAccent(message);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.cardBorderRadius,
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StayNestColors.surfaceLight,
                  borderRadius: AppRadius.cardBorderRadius,
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
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
                        mainAxisSize: MainAxisSize.min,
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
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;

    if (notification == null) return;

    final isPromotion =
        message.data['type']?.toString() == 'property_promotion';
    if (isPromotion && Platform.isIOS) return;
    final imagePath = isPromotion
        ? await _downloadPromotionImage(
            message.data['imageUrl']?.toString() ?? '')
        : null;
    final channel = isPromotion ? _promotionChannel : _channel;

    debugPrint(
        '[FCM] showing local notification id=${notification.hashCode} channel=${channel.id}');
    try {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.high,
            icon: 'ic_launcher_foreground',
            styleInformation: imagePath == null
                ? null
                : BigPictureStyleInformation(
                    FilePathAndroidBitmap(imagePath),
                    contentTitle: notification.title,
                    summaryText: notification.body,
                    hideExpandedLargeIcon: true,
                  ),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (error, stackTrace) {
      debugPrint('[FCM] local notification failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (imagePath != null) {
        try {
          await _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: channel.importance,
                priority: Priority.high,
                icon: 'ic_launcher_foreground',
              ),
            ),
            payload: jsonEncode(message.data),
          );
        } catch (fallbackError) {
          debugPrint(
              '[FCM] text-only local notification failed: $fallbackError');
        }
      }
    }
  }

  Future<String?> _downloadPromotionImage(String value) async {
    if (!isSafePromotionImageUrl(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      final contentType = response.headers.contentType?.mimeType;
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > 5 * 1024 * 1024 ||
          !const {'image/jpeg', 'image/png', 'image/webp'}
              .contains(contentType)) {
        return null;
      }

      final bytes = BytesBuilder(copy: false);
      var totalBytes = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        totalBytes += chunk.length;
        if (totalBytes > 5 * 1024 * 1024) return null;
        bytes.add(chunk);
      }
      if (totalBytes == 0) return null;

      final extension = switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final directory = await getTemporaryDirectory();
      final file = File(path.join(
        directory.path,
        'staynest_promo_${DateTime.now().microsecondsSinceEpoch}.$extension',
      ));
      await file.writeAsBytes(bytes.takeBytes(), flush: true);
      return file.path;
    } catch (error) {
      debugPrint('[FCM] promotion image unavailable: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _removeExpiredPromotionImages() async {
    try {
      final directory = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entity in Directory(directory.path).list()) {
        if (entity is! File ||
            !path.basename(entity.path).startsWith('staynest_promo_')) {
          continue;
        }
        if ((await entity.lastModified()).isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } catch (error) {
      debugPrint('[FCM] promotion image cleanup failed: $error');
    }
  }

  /// Subscribe to a topic (e.g., 'announcements' or 'city_london')
  Future<void> subscribeToTopic(String topic) async {
    if (kIsWeb) return;
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (kIsWeb) return;
    await _messaging.unsubscribeFromTopic(topic);
  }
}
