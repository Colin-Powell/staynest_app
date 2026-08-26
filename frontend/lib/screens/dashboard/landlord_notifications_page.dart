import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/notification_api.dart';
import 'package:property_app/services/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

import 'package:property_app/widgets/property_image.dart';

class LandlordNotificationsPage extends StatefulWidget {
  const LandlordNotificationsPage({super.key});

  static Route route() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          FadeTransition(opacity: animation, child: const LandlordNotificationsPage()),
    );
  }

  @override
  State<LandlordNotificationsPage> createState() => _LandlordNotificationsPageState();
}

class _LandlordNotificationsPageState extends State<LandlordNotificationsPage> {
  // Design Tokens
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);
  final TextEditingController _searchController = TextEditingController();

  // Notification Data mapping the PDF
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    _fcmSubscription = FCMService.instance.notificationsStream.listen((message) {
      final title = message.notification?.title ?? 'Notification';
      final subtitle = message.notification?.body ?? '';
      if (!mounted) return;
      setState(() {
        _notifications.insert(0, {
          'title': title,
          'subtitle': subtitle,
          'time': 'Just now',
          'icon': PhosphorIcons.bell(PhosphorIconsStyle.fill),
          'iconBg': const Color(0xFFFFFFFF),
          'iconColor': primaryGreen,
          'isAvatar': false,
        });
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}';
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await NotificationApi.fetchNotifications(limit: 50);
      final List<dynamic> data = res['data'] ?? [];
      
      if (!mounted) return;
      setState(() {
        _notifications.clear();
        for (var item in data) {
          final created = DateTime.tryParse(item['created_at'].toString())?.toLocal() ?? DateTime.now();
          final type = item['data']?['type']?.toString() ?? '';
          
          IconData icon = PhosphorIcons.bell(PhosphorIconsStyle.fill);
          Color iconColor = primaryGreen;
          Color iconBg = const Color(0xFFFFFFFF);
          
          if (type.contains('booking') || type.contains('checkin') || type.contains('checkout')) {
            icon = PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill);
            iconColor = const Color(0xFF3B82F6);
            iconBg = const Color(0xFFDBEAFE);
          } else if (type.contains('message') || type.contains('unread')) {
            icon = PhosphorIcons.chatCenteredText(PhosphorIconsStyle.fill);
            iconColor = const Color(0xFF8B5CF6);
            iconBg = const Color(0xFFEDE9FE);
          } else if (type.contains('alert') || type.contains('stale')) {
            icon = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
            iconColor = const Color(0xFFEF4444);
            iconBg = const Color(0xFFFEE2E2);
          }

          _notifications.add({
            'title': item['title'] ?? 'Notification',
            'subtitle': item['body'] ?? '',
            'time': _formatTime(created),
            'icon': icon,
            'iconBg': iconBg,
            'iconColor': iconColor,
            'isAvatar': false,
          });
        }
        _isLoading = false;
      });
      NotificationApi.markAllAsRead().catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Suble Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFFFFFFFF).withOpacity(0.4), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildSearchBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _notifications.isEmpty
                          ? const Center(child: Text('No notifications'))
                          : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _NotificationTile(item: _notifications[index]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: textDark, size: 30),
          ),
          Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const Icon(Icons.more_vert, color: textDark, size: 30),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB).withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Notifications',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 17,
                  color: const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search, color: textDark, size: 26),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(color: textDark, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeading(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'],
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      item['time'],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['subtitle'],
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          if (item['unreadCount'] != null) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 25),
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Text(
                item['unreadCount'].toString(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (item['isAvatar']) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipOval(
          child: buildPropertyImage(
            item['avatar'],
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: item['iconBg'],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          item['icon'],
          color: item['iconColor'],
          size: 30,
        ),
      ),
    );
  }
}