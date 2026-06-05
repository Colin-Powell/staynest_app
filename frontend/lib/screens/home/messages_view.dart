import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Local Mock Models for precise matching ──────────────────────────────────
class ChatItem {
  final String id;
  final String name;
  final String avatar;
  final String msg;
  final String time;
  final int unread;
  final bool online;
  final bool isBrand;

  ChatItem({
    required this.id,
    required this.name,
    required this.avatar,
    required this.msg,
    required this.time,
    this.unread = 0,
    this.online = false,
    this.isBrand = false,
  });

  ChatItem copyWith({
    int? unread,
    bool? online,
  }) {
    return ChatItem(
      id: id,
      name: name,
      avatar: avatar,
      msg: msg,
      time: time,
      unread: unread ?? this.unread,
      online: online ?? this.online,
      isBrand: isBrand,
    );
  }
}

class MessagesViewScreen extends StatefulWidget {
  final void Function(String userId, String name, String avatar) onSelectChat;
  final ValueChanged<bool>? onSelectionModeChanged;

  const MessagesViewScreen({
    super.key,
    required this.onSelectChat,
    this.onSelectionModeChanged,
  });

  @override
  State<MessagesViewScreen> createState() => _MessagesViewScreenState();
}

class _MessagesViewScreenState extends State<MessagesViewScreen> {
  final TextEditingController _searchController = TextEditingController();

  // State variables
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<String> _selectedChatIds = {};

  // Mutable list for delete/update operations
  final List<ChatItem> _chats = [
    ChatItem(
        id: 'user_1',
        name: 'John Kamau',
        avatar: 'assets/images/hero.jpg',
        msg: 'Hi, is the room still available?',
        time: '2m',
        unread: 2,
        online: false),
    ChatItem(
        id: 'user_2',
        name: 'Mary Wanjiku',
        avatar: 'assets/images/hero1.jpg',
        msg: 'Are you available for visit?',
        time: '1h',
        unread: 0,
        online: true),
    ChatItem(
        id: 'user_3',
        name: 'GreenHomes Ltd.',
        avatar: 'assets/images/logo_green.png',
        msg: 'Hi, is the room still available?',
        time: '9:15 AM',
        unread: 0,
        isBrand: true),
    ChatItem(
        id: 'user_4',
        name: 'Mary Wanjiru',
        avatar: 'assets/images/hero2.jpg',
        msg: 'Thanks for the info.',
        time: 'Yesterday',
        unread: 0,
        online: false),
    ChatItem(
        id: 'user_5',
        name: 'David Odhiambo',
        avatar: 'assets/images/hero3.jpg',
        msg: 'Hi, is the room still available?',
        time: 'Yesterday',
        unread: 0,
        online: true),
    ChatItem(
        id: 'user_6',
        name: 'Support Team',
        avatar: 'assets/images/logo_blue.png',
        msg: 'Hi, is the room still available?',
        time: 'Mon',
        unread: 0,
        isBrand: true),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Simulate network delay (no heavy entrance staggers, keeping it simple & smooth)
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedChatIds.add(id);
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _toggleChatSelection(String id) {
    setState(() {
      if (_selectedChatIds.contains(id)) {
        _selectedChatIds.remove(id);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
          widget.onSelectionModeChanged?.call(false);
        }
      } else {
        _selectedChatIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final filteredChats = _chats
          .where((c) => c.name.toLowerCase().contains(_searchQuery))
          .toList();
      if (_selectedChatIds.length == filteredChats.length) {
        _selectedChatIds.clear();
        _isSelectionMode = false;
        widget.onSelectionModeChanged?.call(false);
      } else {
        _selectedChatIds = filteredChats.map((c) => c.id).toSet();
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _deleteSelected() {
    setState(() {
      _chats.removeWhere((c) => _selectedChatIds.contains(c.id));
      _exitSelectionMode();
    });
  }

  void _markSelectedAsRead() {
    setState(() {
      for (int i = 0; i < _chats.length; i++) {
        if (_selectedChatIds.contains(_chats[i].id)) {
          _chats[i] = _chats[i].copyWith(unread: 0);
        }
      }
      _exitSelectionMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _chats
        .where((c) => c.name.toLowerCase().contains(_searchQuery))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Smooth Header Transition
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: _isSelectionMode
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: _buildNormalHeader(),
                        secondChild:
                            _buildSelectionHeader(filteredChats.length),
                      ),
                      const SizedBox(height: 24),
                      // Search Bar
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                              color: const Color(0xFFE5E7EB), width: 1.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: Colors.black, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Search Messages',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.black, size: 18),
                                ),
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? _buildLoadingState()
                        : filteredChats.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                  top: 8,
                                  bottom:
                                      MediaQuery.of(context).padding.bottom +
                                          140, // Pad for bottom bar
                                ),
                                itemCount: filteredChats.length,
                                itemBuilder: (context, i) {
                                  final chat = filteredChats[i];
                                  final isSelected =
                                      _selectedChatIds.contains(chat.id);

                                  return Dismissible(
                                    key: ValueKey(chat.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 8, left: 12, right: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.centerRight,
                                      child: const Icon(Icons.delete_outline,
                                          color: Colors.white, size: 32),
                                    ),
                                    onDismissed: (direction) {
                                      setState(() {
                                        _chats.removeWhere(
                                            (c) => c.id == chat.id);
                                        _selectedChatIds.remove(chat.id);
                                        if (_selectedChatIds.isEmpty) {
                                          _isSelectionMode = false;
                                          widget.onSelectionModeChanged
                                              ?.call(false);
                                        }
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('${chat.name} deleted'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    child: _ChatTile(
                                      chat: chat,
                                      isSelectionMode: _isSelectionMode,
                                      isSelected: isSelected,
                                      onTap: () {
                                        if (_isSelectionMode) {
                                          _toggleChatSelection(chat.id);
                                        } else {
                                          widget.onSelectChat(
                                              chat.id, chat.name, chat.avatar);
                                        }
                                      },
                                      onLongPress: () {
                                        if (!_isSelectionMode) {
                                          _toggleSelectionMode(chat.id);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),

            // Bottom Selection Action Bar (Smooth Slide)
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
                        color: const Color(0xFF3F37C9).withOpacity(0.08),
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
                        onTap: _exitSelectionMode,
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
                            Text('More',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black)),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        offset: const Offset(0, -160),
                        onSelected: (value) {
                          if (value == 'read') _markSelectedAsRead();
                          if (value == 'block') _exitSelectionMode();
                          if (value == 'pin') _exitSelectionMode();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'pin',
                            child: Row(children: [
                              Icon(Icons.push_pin_outlined,
                                  size: 20, color: Colors.black),
                              SizedBox(width: 12),
                              Text('Pin',
                                  style: TextStyle(fontWeight: FontWeight.w600))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'read',
                            child: Row(children: [
                              Icon(Icons.mark_chat_read_outlined,
                                  size: 20, color: Colors.black),
                              SizedBox(width: 12),
                              Text('Mark as read',
                                  style: TextStyle(fontWeight: FontWeight.w600))
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Row(children: [
                              Icon(Icons.block_outlined,
                                  color: Color(0xFFEF4444), size: 20),
                              SizedBox(width: 12),
                              Text('Block',
                                  style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w600))
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

  // ── Headers ───────────────────────────────────────────────────────────

  Widget _buildNormalHeader() {
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
            const PopupMenuItem(
                value: 'read',
                child: Text('Mark all as read',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete selected',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            const PopupMenuItem(
                value: 'unread',
                child: Text('Filter by unread',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            const PopupMenuItem(
                value: 'filter',
                child: Text('More filters',
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(int totalChats) {
    bool allSelected = _selectedChatIds.length == totalChats && totalChats > 0;
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
              '${_selectedChatIds.length} Selected',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: _selectAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: allSelected
                  ? const Color(0xFF3F37C9).withOpacity(0.1)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  allSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: allSelected
                      ? const Color(0xFF3F37C9)
                      : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: allSelected
                        ? const Color(0xFF3F37C9)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── States ───────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: 6,
      itemBuilder: (context, i) => Padding(
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          Text('No messages found',
              style: (Theme.of(context).textTheme.headlineSmall ??
                      const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))
                  .copyWith(color: Colors.black)),
          const SizedBox(height: 8),
          const Text('Try adjusting your search query.',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

// ── Chat list tile ────────────────────────────────────────────────────────────
class _ChatTile extends StatefulWidget {
  final ChatItem chat;
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
        // Using a fixed margin prevents layout jumping. The background color simply transitions.
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFEEF2FF)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Checkbox Animation for Selection Mode (Smooth Size Transition)
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
                                ? const Color(0xFF3F37C9)
                                : const Color(0xFFD1D5DB),
                            size: 24,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              // Avatar with online dot
              Stack(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.isBrand
                          ? Colors.transparent
                          : const Color(0xFFE5E7EB),
                      image: c.isBrand
                          ? null
                          : DecorationImage(
                              image: AssetImage(c.avatar), fit: BoxFit.cover),
                    ),
                    child: c.isBrand
                        ? Image.asset(c.avatar,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.domain, color: Colors.grey))
                        : null,
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
                              width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),

              // Text content
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
                                ? const Color(0xFF3F37C9)
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
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
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
      decoration: const BoxDecoration(
        color: Color(0xFF3F37C9),
        shape: BoxShape.circle,
      ),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
