// START OF FILE
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'dart:ui';

// ─── Local UI model (maps from ConversationModel) ────────────────────────────

const Color _tenantPrimary = Color(0xFF3F37C9);

class _ChatItem {
  final String id; // userId of other participant
  final String name;
  final String? avatarUrl;
  final String msg;
  final String time;
  int unread = 0;
  bool online;
  final DateTime? lastMessageAt;

  _ChatItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.msg,
    required this.time,
    this.lastMessageAt,
    this.unread = 0,
    this.online = false,
  });
}

enum _MessageFilter { all, unread, tenants, archived }

// ─── Screen ───────────────────────────────────────────────────────────────────

class MessagesViewScreen extends StatefulWidget {
  final void Function(String userId, String name, String? avatarUrl)
      onSelectChat;
  final ValueChanged<bool>? onSelectionModeChanged;

  const MessagesViewScreen({
    super.key,
    required this.onSelectChat,
    this.onSelectionModeChanged,
  });

  @override
  State<MessagesViewScreen> createState() => _MessagesViewScreenState();
}

class _MessagesViewScreenState extends State<MessagesViewScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  _MessageFilter _currentFilter = _MessageFilter.all;
  Set<String> _selectedIds = {};

  List<_ChatItem> _chats = [];
  List<_ChatItem> _suggestedContacts = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _presenceSubscription;
  late AnimationController _skeletonController;

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadConversations();
    _loadSuggestions();
    _setupSocketListener();
  }

  void _setupSocketListener() {
    _messageSubscription = SocketService.instance.messages.listen((msg) {
      final currentUserId = AppSession.currentUserId;
      final otherId = msg.from == currentUserId ? msg.to : msg.from;

      final index = _chats.indexWhere((c) => c.id == otherId);
      if (index != -1) {
        setState(() {
          final chat = _chats[index];
          _chats[index] = _ChatItem(
            id: chat.id,
            name: chat.name,
            avatarUrl: chat.avatarUrl,
            msg: msg.text,
            time: _formatTime(DateTime.fromMillisecondsSinceEpoch(msg.ts)),
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(msg.ts),
            unread: msg.from != currentUserId ? chat.unread + 1 : chat.unread,
            online: chat.online,
          );
          // Move to top
          final item = _chats.removeAt(index);
          _chats.insert(0, item);
        });
      } else {
        // New conversation we don't have in list yet
        _loadConversations();
      }
    });

    _presenceSubscription = SocketService.instance.presence.listen((data) {
      final userId = data['userId']?.toString();
      final isOnline = data['online'] == true;
      final idx = _chats.indexWhere((c) => c.id == userId);
      if (idx != -1) {
        setState(() => _chats[idx].online = isOnline);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    _skeletonController.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadSuggestions() async {
    final contacts = await MessageService.instance.fetchRecentContacts();
    if (!mounted) return;
    setState(() {
      _suggestedContacts = contacts
          .map((c) => _ChatItem(
                id: c.userId,
                name: c.userName,
                avatarUrl: c.userAvatar,
                msg: 'Contact to start chat',
                time: '',
              ))
          .toList();
    });
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conversations = await MessageService.instance.fetchConversations();
      setState(() {
        _chats = conversations
            .map((c) => _ChatItem(
                  id: c.userId,
                  name: c.userName,
                  avatarUrl: c.userAvatar,
                  msg: c.lastMessage ?? 'No messages yet',
                  time: _formatTime(c.lastMessageAt),
                  lastMessageAt: c.lastMessageAt,
                  unread: c.unreadCount,
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load conversations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    return '${dt.day}/${dt.month}';
  }

  // ── Selection mode ──────────────────────────────────────────────────────────

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _toggleChatSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
          widget.onSelectionModeChanged?.call(false);
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<_ChatItem> filtered) {
    setState(() {
      if (_selectedIds.length == filtered.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
        widget.onSelectionModeChanged?.call(false);
      } else {
        _selectedIds = filtered.map((c) => c.id).toSet();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  Future<void> _deleteSelected() async {
    final idsToDelete = _selectedIds.toList();
    setState(() {
      _chats.removeWhere((c) => idsToDelete.contains(c.id));
      _exitSelectionMode();
    });

    try {
      for (final id in idsToDelete) {
        await MessageService.instance.deleteConversation(id);
      }
    } catch (e) {
      debugPrint('Failed to delete conversations: $e');
      // Re-sync with backend if deletion fails
      _loadConversations();
    }
  }

  Future<void> _markSelectedAsRead() async {
    try {
      final idsToMark = _selectedIds.toList();
      // Call backend via service
      await MessageService.instance.markAsRead(idsToMark);

      setState(() {
        for (final c in _chats) {
          if (idsToMark.contains(c.id)) c.unread = 0;
        }
        _exitSelectionMode();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read: ${e.toString()}')),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Iterable<_ChatItem> filtered =
        _chats.where((c) => c.name.toLowerCase().contains(_searchQuery));

    if (_currentFilter == _MessageFilter.unread) {
      filtered = filtered.where((c) => c.unread > 0);
    } else if (_currentFilter == _MessageFilter.archived) {
      // Placeholder logic for archived
      filtered = filtered.where((c) => false);
    }

    final displayList = filtered.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Color(0xFFF9FAFB),
                    Color(0xFFF3F4F6),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _isSelectionMode
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: _buildNormalHeader(displayList.length),
                        secondChild: _buildSelectionHeader(displayList.length),
                      ),
                      const SizedBox(height: 24),
                      _buildFilterChips(),
                      const SizedBox(height: 16),
                      // CLEAN SEARCH BAR UI
                      _GlassContainer(
                        padding: EdgeInsets.zero,
                        height: 52,
                        borderRadius: BorderRadius.circular(26),
                        opacity: 0.6,
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Icon(Icons.search_rounded,
                                  color: Colors.black, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                // Disabling native fill and borders to prevent double-pill visual
                                decoration: const InputDecoration(
                                  hintText: 'Search Messages',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 16),
                                  child: Icon(
                                    Icons.cancel,
                                    color: Color(0xFF9CA3AF),
                                    size: 22,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? _buildLoadingState()
                        : _errorMessage != null
                            ? _buildErrorState()
                            : displayList.isEmpty
                                ? _buildEmptyState()
                                : RefreshIndicator(
                                    onRefresh: _loadConversations,
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.only(
                                        left: 12,
                                        right: 12,
                                        top: 8,
                                        bottom: MediaQuery.of(context)
                                                .padding
                                                .bottom +
                                            140,
                                      ),
                                      itemCount: displayList.length,
                                      itemBuilder: (context, i) {
                                        final chat = displayList[i];
                                        final isSelected =
                                            _selectedIds.contains(chat.id);

                                        return Dismissible(
                                          key: ValueKey(chat.id),
                                          direction:
                                              DismissDirection.horizontal,
                                          background: Container(
                                            // Swipe Right: Mute
                                            margin: const EdgeInsets.only(
                                                bottom: 8, left: 12, right: 12),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade700,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: const Row(
                                              children: [
                                                Icon(
                                                    Icons
                                                        .notifications_off_outlined,
                                                    color: Colors.white,
                                                    size: 28),
                                                SizedBox(width: 12),
                                                Text('Mute',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          secondaryBackground: Container(
                                            // Swipe Left: Delete
                                            margin: const EdgeInsets.only(
                                                bottom: 8, left: 12, right: 12),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            alignment: Alignment.centerRight,
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Text('Delete',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                SizedBox(width: 12),
                                                Icon(Icons.delete_outline,
                                                    color: Colors.white,
                                                    size: 28),
                                              ],
                                            ),
                                          ),
                                          onDismissed: (direction) async {
                                            if (direction ==
                                                DismissDirection.endToStart) {
                                              _selectedIds = {chat.id};
                                              await _deleteSelected();
                                            } else {
                                              // Handle Mute
                                              _loadConversations();
                                            }
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content:
                                                  Text('${chat.name} deleted'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ));
                                          },
                                          child: _ChatTile(
                                            chat: chat,
                                            isSelectionMode: _isSelectionMode,
                                            isSelected: isSelected,
                                            onTap: () {
                                              if (_isSelectionMode) {
                                                _toggleChatSelection(chat.id);
                                              } else {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/chat',
                                                  arguments: <String, String>{
                                                    'userId': chat.id,
                                                    'name': chat.name,
                                                    'avatar':
                                                        chat.avatarUrl ?? '',
                                                  },
                                                ).then((_) =>
                                                    _loadConversations());
                                              }
                                            },
                                            onLongPress: () {
                                              if (!_isSelectionMode) {
                                                _enterSelectionMode(chat.id);
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                  ),
                ),
              ],
            ),

            // Bottom selection bar
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSlide(
                offset: _isSelectionMode ? Offset.zero : const Offset(0, 1.2),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutQuad,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _tenantPrimary.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, -10),
                      ),
                    ],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BottomBarIcon(
                        icon: Icons.notifications_off_outlined,
                        label: 'Mute',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mute coming soon')),
                          );
                        },
                      ),
                      _BottomBarIcon(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: const Color(0xFFEF4444),
                        onTap: _deleteSelected,
                      ),
                      PopupMenuButton<String>(
                        icon: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.more_vert_rounded,
                                color: Colors.black, size: 28),
                            const SizedBox(height: 4),
                            Text(
                              'More',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                            ),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        offset: const Offset(0, -160),
                        onSelected: (value) {
                          if (value == 'read') _markSelectedAsRead();
                          if (value == 'block' || value == 'pin') {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    '${value[0].toUpperCase()}${value.substring(1)} coming soon')));
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'pin',
                            child: Row(children: [
                              Icon(Icons.push_pin_outlined,
                                  size: 20, color: Colors.black),
                              SizedBox(width: 12),
                              Text('Pin',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'read',
                            child: Row(children: [
                              Icon(Icons.mark_chat_read_outlined,
                                  size: 20, color: Colors.black),
                              SizedBox(width: 12),
                              Text('Mark as read',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Row(children: [
                              Icon(Icons.block_outlined,
                                  color: Color(0xFFEF4444), size: 20),
                              SizedBox(width: 12),
                              Text('Block',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _MessageFilter.values.map((filter) {
          final isSelected = _currentFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label:
                  Text(filter.name[0].toUpperCase() + filter.name.substring(1)),
              selected: isSelected,
              onSelected: (val) => setState(() => _currentFilter = filter),
              selectedColor: _tenantPrimary.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? _tenantPrimary : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: StadiumBorder(
                  side: BorderSide(
                      color: isSelected ? _tenantPrimary : Colors.black12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Headers ──────────────────────────────────────────────────────────────────

  Widget _buildNormalHeader(int total) {
    return Row(
      key: const ValueKey('normalHeader'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Messages',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: Colors.black, size: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'read',
                child: Text('Mark all ($total) as read',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            PopupMenuItem(
                value: 'unread',
                child: Text(
                    _currentFilter == _MessageFilter.unread
                        ? 'Show all'
                        : 'Filter by unread',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
          onSelected: (val) {
            if (val == 'read') {
              MessageService.instance
                  .markAsRead(_chats.map((e) => e.id).toList())
                  .then((_) => _loadConversations());
            } else if (val == 'unread') {
              // Legacy menu support
              setState(() {
                _currentFilter = _currentFilter == _MessageFilter.unread
                    ? _MessageFilter.all
                    : _MessageFilter.unread;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(int totalFiltered) {
    final allSelected =
        _selectedIds.length == totalFiltered && totalFiltered > 0;
    return Row(
      key: const ValueKey('selectionHeader'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _exitSelectionMode,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.close_rounded,
                    size: 22, color: Colors.black),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${_selectedIds.length} Selected',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _selectAll(_chats
              .where((c) => c.name.toLowerCase().contains(_searchQuery))
              .toList()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: allSelected
                  ? _tenantPrimary.withOpacity(0.1)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  allSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: allSelected ? _tenantPrimary : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                        allSelected ? _tenantPrimary : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── States ───────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, i) => FadeTransition(
        opacity: _skeletonController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB), shape: BoxShape.circle),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 16,
                        width: 140,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 10),
                    Container(
                        height: 14,
                        width: 220,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadConversations,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_searchQuery.isEmpty && _suggestedContacts.isNotEmpty) ...[
            Text(
              'Start a conversation',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _suggestedContacts.length,
                itemBuilder: (context, i) {
                  final contact = _suggestedContacts[i];
                  return GestureDetector(
                    onTap: () => widget.onSelectChat(
                        contact.id, contact.name, contact.avatarUrl),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Column(
                        children: [
                          ClipOval(
                            child: AppSession.buildAvatar(
                              contact.avatarUrl ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            contact.name.split(' ')[0],
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 40),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isEmpty
                  ? 'No conversations yet'
                  : 'No messages found',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Your conversations will appear here.'
                  : 'Try adjusting your search query.',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF)),
            ),
          ]
        ],
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderWidth;
  final double? height;

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────

class _ChatTile extends StatefulWidget {
  final _ChatItem chat;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatTile({
    required this.chat,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 0.97).animate(
    CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.chat;
    final bool hasUnread = c.unread > 0;

    return GestureDetector(
      onTapDown: (_) => _hoverCtrl.forward(),
      onTapUp: (_) {
        _hoverCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverCtrl.reverse(),
      onLongPress: () {
        _hoverCtrl.reverse();
        widget.onLongPress();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _GlassContainer(
            opacity: widget.isSelected ? 0.8 : 0.55,
            borderWidth: widget.isSelected ? 2.0 : 1.5,
            padding: const EdgeInsets.all(12),
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                // Accent bar for unread
                if (hasUnread && !widget.isSelectionMode)
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _tenantPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (hasUnread && !widget.isSelectionMode)
                  const SizedBox(width: 8),

                // Selection checkbox
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: widget.isSelectionMode ? 36 : 0,
                    child: widget.isSelectionMode
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              widget.isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: widget.isSelected
                                  ? _tenantPrimary
                                  : const Color(0xFFD1D5DB),
                              size: 24,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE5E7EB),
                      ),
                      child: ClipOval(
                        child: AppSession.buildAvatar(
                          c.avatarUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (c.online)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isSelected
                                  ? const Color(0xFFEEF2FF)
                                  : const Color(0xFFF8F9FA),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.black,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.time,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: hasUnread
                                  ? _tenantPrimary
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.msg,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: widget.isSelected
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 12),
                            _UnreadBadge(count: c.unread),
                          ],
                        ],
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
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration:
          const BoxDecoration(color: _tenantPrimary, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _BottomBarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BottomBarIcon({
    required this.icon,
    required this.label,
    this.color = Colors.black,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
