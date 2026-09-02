import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:property_app/services/fcm_service.dart';
import 'package:property_app/services/notification_api.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const _bg = Color(0xFFFAFAFA);
const _dark = Color(0xFF111827);
const _grey = Color(0xFF9CA3AF);
const _primaryText = Color(0xFF4F70F8);
const _surface = Colors.white;

// ─── Model ────────────────────────────────────────────────────────────────────
class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String emoji;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.emoji = '🔔',
    this.isRead = false,
  });
}

// ─── View ─────────────────────────────────────────────────────────────────────
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;
  late final AnimationController _staggerCtrl;

  final List<NotificationItem> _items = [];
  bool _isLoading = true;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  Stream<RemoteMessage>? _stream;

  @override
  void initState() {
    super.initState();

    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pageCtrl.forward().then((_) => _staggerCtrl.forward());

    _loadNotifications();
    _setupFCMStream();
  }

  String _notificationEmoji(Map<dynamic, dynamic> data) {
    final type = data['type']?.toString().toLowerCase() ?? '';
    if (type.contains('booking') ||
        type.contains('checkin') ||
        type.contains('checkout')) return '📅';
    if (type.contains('message') || type.contains('unread')) return '💬';
    if (type.contains('payment') || type.contains('price')) return '💰';
    if (type.contains('alert') ||
        type.contains('warning') ||
        type.contains('stale')) return '⚠️';
    if (type.contains('approved') || type.contains('success')) return '✅';
    return '🔔';
  }

  void _setupFCMStream() {
    _stream = FCMService.instance.notificationsStream;
    _stream!.listen((message) {
      if (!mounted) return;
      final title = message.notification?.title ?? 'Notification';
      final subtitle = message.notification?.body ?? '';
      final emoji = _notificationEmoji(message.data);
      final now = DateTime.now();

      setState(() {
        _items.insert(
          0,
          NotificationItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            subtitle: subtitle,
            time: _formatTime(now),
            emoji: emoji,
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
          final created =
              DateTime.tryParse(item['created_at'].toString())?.toLocal() ??
                  DateTime.now();
          final dataMap = item['data'] ?? {};
          final unreadCount =
              int.tryParse(dataMap['unreadCount']?.toString() ?? '') ?? 0;

          _items.add(NotificationItem(
            id: item['id']?.toString() ?? UniqueKey().toString(),
            title: item['title'] ?? 'Notification',
            subtitle: item['body'] ?? '',
            time: _formatTime(created),
            emoji: _notificationEmoji(dataMap),
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
    _staggerCtrl.dispose();
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isSelectionMode
            ? Row(
                key: const ValueKey('selection_header'),
                children: [
                  GestureDetector(
                    onTap: _toggleSelectionMode,
                    child: const Icon(PhosphorIconsRegular.x,
                        color: _dark, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${_selectedIds.length} Selected',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _selectAll,
                    child: const Icon(PhosphorIconsRegular.checkSquareOffset,
                        color: _dark, size: 28),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('normal_header'),
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(PhosphorIconsRegular.caretLeft,
                          color: _dark, size: 20),
                    ),
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
                    icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
                        color: _dark, size: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    elevation: 4,
                    onSelected: (value) {
                      if (value == 'read_all') _markAllAsRead();
                      if (value == 'select') _toggleSelectionMode();
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'read_all',
                        child: Text('Mark all as read',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500)),
                      ),
                      PopupMenuItem(
                        value: 'select',
                        child: Text('Select messages',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(PhosphorIconsRegular.bellSlash, color: _grey, size: 64),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get updates, they\'ll show up here.',
            style: GoogleFonts.poppins(fontSize: 14, color: _grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(int index, NotificationItem item) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    final isSelected = _selectedIds.contains(item.id);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(animation),
        child: GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() => _isSelectionMode = true);
            }
            _toggleItemSelection(item.id);
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleItemSelection(item.id);
            } else {
              setState(() => item.isRead = true);
              // Handle regular tap (navigation, etc)
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  item.isRead ? Colors.white : _primaryText.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? _primaryText
                    : (item.isRead
                        ? Colors.transparent
                        : _primaryText.withOpacity(0.1)),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: item.isRead
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 16, top: 4),
                    child: Icon(
                      isSelected
                          ? PhosphorIconsRegular.checkCircle
                          : PhosphorIconsRegular.circle,
                      color: isSelected ? _primaryText : _grey,
                      size: 24,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.isRead ? _bg : _primaryText.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        Text(item.emoji, style: const TextStyle(fontSize: 20)),
                  ),
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
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
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
                              color: item.isRead ? _grey : _primaryText,
                              fontWeight: item.isRead
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _grey,
                          fontWeight: FontWeight.w400,
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
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: _isSelectionMode ? 32 : -100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _dark,
          borderRadius: BorderRadius.circular(32), // Pill shape
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: _selectedIds.isEmpty ? null : _markSelectedAsRead,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.envelopeOpen,
                      color: _selectedIds.isEmpty
                          ? _grey.withOpacity(0.5)
                          : Colors.white),
                  const SizedBox(height: 4),
                  Text('Read',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _selectedIds.isEmpty
                              ? _grey.withOpacity(0.5)
                              : Colors.white)),
                ],
              ),
            ),
            Container(width: 1, height: 30, color: _grey.withOpacity(0.3)),
            GestureDetector(
              onTap: _selectedIds.isEmpty ? null : _deleteSelected,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.trash,
                      color: _selectedIds.isEmpty
                          ? _grey.withOpacity(0.5)
                          : const Color(0xFFEF4444)), // Red
                  const SizedBox(height: 4),
                  Text('Delete',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _selectedIds.isEmpty
                              ? _grey.withOpacity(0.5)
                              : const Color(0xFFEF4444))),
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
                    _buildHeader(),
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoading()
                          : _items.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      MediaQuery.of(context).padding.bottom +
                                          100),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _items.length,
                                  itemBuilder: (context, index) {
                                    return _buildNotificationItem(
                                        index, _items[index]);
                                  },
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
