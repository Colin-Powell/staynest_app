import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'landlord_chat_view.dart';
import 'package:uuid/uuid.dart';

const Color _landlordPrimary = Color(0xFF059669);
const Color _textDark = Color(0xFF111827);
const Color _textLight = Color(0xFF9CA3AF);

enum _LandlordFilter { all, applicants, tenants, archived }

class LandlordMessagesPage extends StatefulWidget {
  final VoidCallback onChatOpen;
  final VoidCallback onChatClose;

  const LandlordMessagesPage({
    super.key,
    required this.onChatOpen,
    required this.onChatClose,
  });

  @override
  State<LandlordMessagesPage> createState() => _LandlordMessagesPageState();
}

class _LandlordMessagesPageState extends State<LandlordMessagesPage> {
  ConversationModel? _selectedConversation;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSelectionMode = false;
  _LandlordFilter _currentFilter = _LandlordFilter.all;
  Set<String> _selectedIds = {};
  Set<String> _onlineUserIds = {};

  List<ConversationModel> _conversations = [];
  List<ConversationModel> _suggestedTenants = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadConversations();
    _loadSuggested();
    _setupSocketListener();
  }

  Future<void> _loadSuggested() async {
    final contacts = await MessageService.instance.fetchRecentContacts();
    if (mounted) setState(() => _suggestedTenants = contacts);
  }

  void _setupSocketListener() {
    _messageSubscription = SocketService.instance.messages.listen((msg) {
      final currentUserId = AppSession.currentUserId;
      final otherId = msg.from == currentUserId ? msg.to : msg.from;

      final index = _conversations.indexWhere((c) => c.userId == otherId);
      if (index != -1) {
        setState(() {
          final old = _conversations[index];
          _conversations[index] = ConversationModel(
            userId: old.userId,
            userName: old.userName,
            userAvatar: old.userAvatar,
            lastMessage: msg.text,
            lastMessageAt: DateTime.fromMillisecondsSinceEpoch(msg.ts),
            unreadCount: msg.from != currentUserId
                ? old.unreadCount + 1
                : old.unreadCount,
          );
          final item = _conversations.removeAt(index);
          _conversations.insert(0, item);
        });
      } else {
        _loadConversations();
      }
    });

    _presenceSubscription = SocketService.instance.presence.listen((data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      setState(() {
        if (data['online'] == true) {
          _onlineUserIds.add(userId);
        } else {
          _onlineUserIds.remove(userId);
        }
      });
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
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load messages: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }

  List<ConversationModel> get _filteredConversations {
    Iterable<ConversationModel> filtered = _conversations;

    if (_currentFilter == _LandlordFilter.archived) {
      filtered = filtered.where((c) => false);
    }

    if (_searchQuery.isEmpty) return filtered.toList();
    return filtered
        .where((conv) =>
            conv.userName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
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

  Widget _buildConversationsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _landlordPrimary),
      );
    }

    if (_errorMessage != null) {
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

    if (_filteredConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mail_outline, size: 48, color: _textLight),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Messages will appear here',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _textLight),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredConversations;

    return RefreshIndicator(
      color: _landlordPrimary,
      onRefresh: _loadConversations,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 160),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final conv = filtered[index];
          final isSelected = _selectedIds.contains(conv.userId);

          return Dismissible(
            key: ValueKey(conv.userId),
            direction: DismissDirection.horizontal,
            background: Container(
              // Swipe Right: Mute
              margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  Icon(Icons.notifications_off_outlined,
                      color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Mute',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            secondaryBackground: Container(
              // Swipe Left: Delete
              margin: const EdgeInsets.only(bottom: 12, left: 12, right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerRight,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Delete',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 12),
                  Icon(Icons.delete_outline, color: Colors.white, size: 28),
                ],
              ),
            ),
            onDismissed: (direction) async {
              if (direction == DismissDirection.endToStart) {
                final userId = conv.userId;
                setState(() =>
                    _conversations.removeWhere((c) => c.userId == userId));
                await MessageService.instance.deleteConversation(userId);
              } else {
                _loadConversations();
              }
            },
            child: _ConversationTile(
              name: conv.userName,
              avatarUrl: conv.userAvatar,
              lastMessage: conv.lastMessage ?? 'No messages yet',
              time: _formatTime(conv.lastMessageAt),
              unread: conv.unreadCount,
              isOnline: _onlineUserIds.contains(conv.userId),
              isSelected: isSelected,
              isSelectionMode: _isSelectionMode,
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(conv.userId);
                } else {
                  widget.onChatOpen();
                  setState(() => _selectedConversation = conv);
                }
              },
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.add(conv.userId);
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _filteredConversations.length) {
        _exitSelectionMode();
      } else {
        _selectedIds = _filteredConversations.map((c) => c.userId).toSet();
      }
    });
  }

  Future<void> _markSelectedAsRead() async {
    try {
      final idsToMark = _selectedIds.toList();
      await MessageService.instance.markAsRead(idsToMark);
      _exitSelectionMode();
      _loadConversations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedConversation != null) {
      final conv = _selectedConversation!;
      return LandlordChatView(
        onBack: () {
          widget.onChatClose();
          setState(() => _selectedConversation = null);
        },
        name: conv.userName,
        avatar: conv.userAvatar,
        userId: conv.userId,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF7FDF9),
                    Color(0xFFE8F6EF),
                    Color(0xFFD4EFE1),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 32,
                  right: 32,
                  bottom: 24,
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isSelectionMode
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildNormalHeader(),
                  secondChild: _buildSelectionHeader(),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildFilterChips(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search Messages',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _textLight,
                          ),
                          prefixIcon: const Icon(Icons.search,
                              color: _textDark, size: 24),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 14, color: _textDark),
                                  ),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildConversationsList()),
            ],
          ),
          _buildBottomSelectionBar(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _LandlordFilter.values.map((filter) {
          final isSelected = _currentFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label:
                  Text(filter.name[0].toUpperCase() + filter.name.substring(1)),
              selected: isSelected,
              onSelected: (val) => setState(() => _currentFilter = filter),
              selectedColor: _landlordPrimary.withOpacity(0.2),
              labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isSelected ? _landlordPrimary : _textDark,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
              backgroundColor: Colors.white.withOpacity(0.5),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNormalHeader() {
    return Text(
      'Messages',
      style: GoogleFonts.poppins(
          fontSize: 32, fontWeight: FontWeight.w800, color: _textDark),
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: _textDark),
              onPressed: _exitSelectionMode,
            ),
            const SizedBox(width: 8),
            Text(
              '${_selectedIds.length} Selected',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _textDark),
            ),
          ],
        ),
        TextButton(
          onPressed: _selectAll,
          child: Text(_selectedIds.length == _filteredConversations.length
              ? 'Unselect All'
              : 'Select All'),
        ),
      ],
    );
  }

  Widget _buildBottomSelectionBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSlide(
        offset: _isSelectionMode ? Offset.zero : const Offset(0, 1.2),
        duration: const Duration(milliseconds: 250),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.of(context).padding.bottom + 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomBarIcon(
                  icon: Icons.notifications_off_outlined,
                  label: 'Mute',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mute coming soon')));
                  }),
              _BottomBarIcon(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () async {
                  final ids = _selectedIds.toList();
                  setState(() => _conversations
                      .removeWhere((c) => ids.contains(c.userId)));
                  for (var id in ids)
                    await MessageService.instance.deleteConversation(id);
                  _exitSelectionMode();
                },
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, -120),
                onSelected: (value) {
                  if (value == 'read') _markSelectedAsRead();
                },
                icon: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.more_horiz, color: _textDark, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      'More',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'read',
                    child: Row(
                      children: [
                        Icon(Icons.mark_chat_read_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Mark as read'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Glass Container ──────────────────────────────────────────────────

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;
  final double borderWidth;

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: radius,
            border: Border.all(
                color: Colors.white.withOpacity(0.4), width: borderWidth),
          ),
          child: child,
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

  const _BottomBarIcon(
      {required this.icon,
      required this.label,
      this.color = _textDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─── Conversation Tile ───────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isOnline;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.isOnline,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: _GlassContainer(
        padding: const EdgeInsets.all(16),
        opacity: isSelected ? 0.8 : 0.4,
        borderRadius: BorderRadius.circular(28),
        child: Row(
          children: [
            // Visual hierarchy accent bar
            if (unread > 0 && !isSelectionMode)
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: _landlordPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? _landlordPrimary : _textLight,
                ),
              ),
            _buildAvatar(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _textLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textLight,
                  ),
                ),
                const SizedBox(height: 8),
                if (unread > 0)
                  Container(
                    width: unread > 9 ? 32 : 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: _landlordPrimary,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final Widget avatarWidget = avatarUrl != null && avatarUrl!.isNotEmpty
        ? buildPropertyImage(
            avatarUrl!,
            fit: BoxFit.cover,
          )
        : Container(
            color: const Color(0xFFF3F4F6),
            child: const Icon(Icons.person, color: _textLight, size: 32),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
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
          child: ClipOval(child: avatarWidget),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
