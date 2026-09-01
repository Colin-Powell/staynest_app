import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:property_app/services/notification_api.dart';
import 'package:property_app/services/fcm_service.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

// ─── Local UI Model ───────────────────────────────────────────────────────────
class _LandlordNotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  bool isRead;

  _LandlordNotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.isRead = false,
  });
}

class LandlordNotificationsPage extends StatefulWidget {
  const LandlordNotificationsPage({super.key});

  @override
  State<LandlordNotificationsPage> createState() => _LandlordNotificationsPageState();
}

class _LandlordNotificationsPageState extends State<LandlordNotificationsPage>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  final List<_LandlordNotificationItem> _items = [];
  bool _isLoading = true;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  StreamSubscription<RemoteMessage>? _fcmSubscription;

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _pageCtrl.forward();

    _loadNotifications();
    _setupFCMStream();
  }

  void _setupFCMStream() {
    _fcmSubscription = FCMService.instance.notificationsStream.listen((message) {
      if (!mounted) return;
      final title = message.notification?.title ?? 'Notification';
      final subtitle = message.notification?.body ?? '';
      final now = DateTime.now();

      setState(() {
        _items.insert(
          0,
          _LandlordNotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            subtitle: subtitle,
            time: _formatTime(now),
            icon: PhosphorIconsFill.bell,
            iconColor: _green,
            iconBg: _green.withOpacity(0.1),
            isRead: false,
          ),
        );
      });
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final res = await NotificationApi.fetchNotifications(limit: 50);
      final List<dynamic> data = res['data'] ?? [];
      
      if (!mounted) return;
      setState(() {
        _items.clear();
        for (var item in data) {
          final created = DateTime.tryParse(item['created_at'].toString())?.toLocal() ?? DateTime.now();
          final type = item['data']?['type']?.toString() ?? '';
          final dataMap = item['data'] ?? {};
          final unreadCount = int.tryParse(dataMap['unreadCount']?.toString() ?? '') ?? 0;
          
          IconData icon = PhosphorIconsFill.bell;
          Color iconColor = _green;
          Color iconBg = _green.withOpacity(0.1);
          
          if (type.contains('booking') || type.contains('checkin') || type.contains('checkout')) {
            icon = PhosphorIconsFill.calendarCheck;
            iconColor = const Color(0xFF3B82F6); // Blue
            iconBg = const Color(0xFF3B82F6).withOpacity(0.1);
          } else if (type.contains('message') || type.contains('unread')) {
            icon = PhosphorIconsFill.chatTeardropText;
            iconColor = const Color(0xFF8B5CF6); // Purple
            iconBg = const Color(0xFF8B5CF6).withOpacity(0.1);
          } else if (type.contains('alert') || type.contains('stale')) {
            icon = PhosphorIconsFill.warningCircle;
            iconColor = const Color(0xFFEF4444); // Red
            iconBg = const Color(0xFFEF4444).withOpacity(0.1);
          }

          _items.add(_LandlordNotificationItem(
            id: item['id']?.toString() ?? UniqueKey().toString(),
            title: item['title'] ?? 'Notification',
            subtitle: item['body'] ?? '',
            time: _formatTime(created),
            icon: icon,
            iconColor: iconColor,
            iconBg: iconBg,
            isRead: unreadCount == 0,
          ));
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_items.map((e) => e.id));
      }
    });
  }

  void _markSelectedAsRead() {
    setState(() {
      for (var item in _items) {
        if (_selectedIds.contains(item.id)) item.isRead = true;
      }
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    // NotificationApi.markAsRead(ids: _selectedIds.toList()).catchError((_) {});
  }

  void _deleteSelected() {
    setState(() {
      _items.removeWhere((item) => _selectedIds.contains(item.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    // NotificationApi.delete(ids: _selectedIds.toList()).catchError((_) {});
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _items) {
        item.isRead = true;
      }
    });
    NotificationApi.markAllAsRead().catchError((_) {});
  }

  // ─── UI Builders ────────────────────────────────────────────────────────────

  Widget _buildNormalHeader() {
    return Row(
      key: const ValueKey('normal_header'),
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const Icon(PhosphorIconsRegular.caretLeft, color: _dark, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(PhosphorIconsRegular.dotsThreeVertical, color: _dark, size: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: _surface,
          elevation: 4,
          onSelected: (value) {
            if (value == 'read_all') _markAllAsRead();
            if (value == 'select') _toggleSelectionMode();
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'read_all',
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.checkCircle, color: _dark, size: 20),
                  const SizedBox(width: 12),
                  Text('Mark all as read', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'select',
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.checkSquareOffset, color: _dark, size: 20),
                  const SizedBox(width: 12),
                  Text('Select messages', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      key: const ValueKey('selection_header'),
      children: [
        GestureDetector(
          onTap: _toggleSelectionMode,
          behavior: HitTestBehavior.opaque,
          child: const Icon(PhosphorIconsRegular.x, color: _dark, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            '${_selectedIds.length} Selected',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.5,
            ),
          ),
        ),
        GestureDetector(
          onTap: _selectAll,
          behavior: HitTestBehavior.opaque,
          child: Text(
            _selectedIds.length == _items.length ? 'Unselect All' : 'Select All',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 88,
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.bellSlash, color: _grey, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              'When you get updates, alerts, or new bookings, they\'ll show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: _isSelectionMode ? MediaQuery.of(context).padding.bottom + 24 : -100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(32), // Pill shape
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: _selectedIds.isEmpty ? null : _markSelectedAsRead,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.envelopeOpen, color: _selectedIds.isEmpty ? _grey.withOpacity(0.5) : Colors.white, size: 26),
                  const SizedBox(height: 6),
                  Text('Read', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _selectedIds.isEmpty ? _grey.withOpacity(0.5) : Colors.white)),
                ],
              ),
            ),
            Container(width: 1, height: 32, color: _grey.withOpacity(0.3)),
            GestureDetector(
              onTap: _selectedIds.isEmpty ? null : _deleteSelected,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.trash, color: _selectedIds.isEmpty ? _grey.withOpacity(0.5) : const Color(0xFFEF4444), size: 26),
                  const SizedBox(height: 6),
                  Text('Delete', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _selectedIds.isEmpty ? _grey.withOpacity(0.5) : const Color(0xFFEF4444))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isSelectionMode ? _buildSelectionHeader() : _buildNormalHeader(),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoading()
                          : _items.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  color: _green,
                                  backgroundColor: _surface,
                                  onRefresh: _loadNotifications,
                                  child: ListView.builder(
                                    padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.of(context).padding.bottom + 120),
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    itemCount: _items.length,
                                    itemBuilder: (context, index) {
                                      return _NotificationTile(
                                        item: _items[index],
                                        isSelectionMode: _isSelectionMode,
                                        isSelected: _selectedIds.contains(_items[index].id),
                                        onTap: () {
                                          if (_isSelectionMode) {
                                            _toggleItemSelection(_items[index].id);
                                          } else {
                                            setState(() => _items[index].isRead = true);
                                          }
                                        },
                                        onLongPress: () {
                                          if (!_isSelectionMode) {
                                            _toggleSelectionMode();
                                            _toggleItemSelection(_items[index].id);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                    ),
                  ],
                ),
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Notification Tile ───────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final _LandlordNotificationItem item;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotificationTile({
    required this.item,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? _surface : _green.withOpacity(0.04), // Soft green background for unread
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _green : (item.isRead ? _grey.withOpacity(0.15) : _green.withOpacity(0.1)),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: (item.isRead && !isSelected)
              ? []
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 12),
                child: Icon(
                  isSelected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                  color: isSelected ? _green : _grey,
                  size: 24,
                ),
              )
            else if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(right: 12, top: 18),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),

            // Icon Container
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.isRead ? _bg : item.iconBg,
                shape: BoxShape.circle,
                border: item.isRead ? null : Border.all(color: item.iconColor.withOpacity(0.2)),
              ),
              child: Icon(
                item.icon,
                color: item.isRead ? _grey : item.iconColor,
                size: 24,
              ),
            ),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: _dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: item.isRead ? _grey : _green,
                          fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: item.isRead ? _grey : _dark.withOpacity(0.8),
                      fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}