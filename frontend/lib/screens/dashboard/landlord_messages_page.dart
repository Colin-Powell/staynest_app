import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/utils/api_result.dart';
import 'landlord_chat_view.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

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
  final Set<String> _onlineUserIds = {};

  List<ConversationModel> _conversations = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _presenceSubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadConversations();
    _setupSocketListener();
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResult.mapError(e);
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
      filtered = filtered.where((c) => false); // Expand logic later if needed
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

  // ─── ACTIONS ────────────────────────────────────────────────────────────────

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
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiResult.mapError(e))));
    }
  }

  Future<void> _deleteSelected() async {
    try {
      final idsToDelete = _selectedIds.toList();
      setState(() {
        _conversations.removeWhere((c) => idsToDelete.contains(c.userId));
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      for (var id in idsToDelete) {
        await MessageService.instance.deleteConversation(id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiResult.mapError(e))));
    }
  }

  Future<void> _markConversationRead(String userId) async {
    final index = _conversations
        .indexWhere((conversation) => conversation.userId == userId);
    if (index != -1) {
      setState(() {
        _conversations[index] = ConversationModel(
          userId: _conversations[index].userId,
          userName: _conversations[index].userName,
          userAvatar: _conversations[index].userAvatar,
          lastMessage: _conversations[index].lastMessage,
          lastMessageAt: _conversations[index].lastMessageAt,
          unreadCount: 0,
        );
      });
    }

    try {
      await MessageService.instance.markAsRead([userId]);
    } catch (_) {
      // Optimistic state is kept; a later refresh will reconcile.
    }
  }

  // ─── UI BUILDERS ────────────────────────────────────────────────────────────

  Widget _buildNormalHeader() {
    return Row(
      key: const ValueKey('normal_header'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Messages',
          style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -1.0),
        ),
        PopupMenuButton<_LandlordFilter>(
          icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
              color: _dark, size: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          elevation: 4,
          onSelected: (filter) => setState(() => _currentFilter = filter),
          itemBuilder: (context) => _LandlordFilter.values.map((filter) {
            final isSelected = _currentFilter == filter;
            final name =
                filter.name[0].toUpperCase() + filter.name.substring(1);
            return PopupMenuItem(
              value: filter,
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    color: isSelected ? _green : _grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? _green : _dark,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Row(
      key: const ValueKey('selection_header'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _exitSelectionMode,
              child: const Icon(PhosphorIconsRegular.x, color: _dark, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              '${_selectedIds.length} Selected',
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.4),
            ),
          ],
        ),
        GestureDetector(
          onTap: _selectAll,
          child: const Icon(PhosphorIconsRegular.checkSquareOffset,
              color: _dark, size: 28),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(PhosphorIconsRegular.magnifyingGlass,
                color: _dark, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
              decoration: InputDecoration(
                hintText: 'Search Messages',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w400, color: _grey),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                FocusScope.of(context).unfocus();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(PhosphorIconsFill.xCircle, color: _grey, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 160),
      itemCount: 6,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Divider(color: _grey.withOpacity(0.1), height: 1),
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: 120,
                          height: 16,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4))),
                    ),
                  ],
                ),
              ),
            ],
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
          const Icon(PhosphorIconsRegular.chatTeardropSlash,
              size: 64, color: _grey),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
          ),
          const SizedBox(height: 8),
          Text(
            'When tenants contact you, messages will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 14, color: _grey),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) return _buildShimmerLoading();

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.warningCircle,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  color: _dark, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadConversations,
              child: Text('Retry',
                  style: GoogleFonts.poppins(
                      color: _green, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    if (_filteredConversations.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadConversations,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            24, 8, 24, MediaQuery.of(context).padding.bottom + 160),
        itemCount: _filteredConversations.length,
        separatorBuilder: (_, __) =>
            Divider(color: _grey.withOpacity(0.1), height: 1),
        itemBuilder: (context, index) {
          final conv = _filteredConversations[index];
          final isSelected = _selectedIds.contains(conv.userId);

          return Dismissible(
            key: ValueKey(conv.userId),
            direction: DismissDirection.endToStart, // Only swipe to delete
            background: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              child: const Icon(PhosphorIconsRegular.trash,
                  color: Colors.white, size: 28),
            ),
            onDismissed: (direction) async {
              final userId = conv.userId;
              setState(
                  () => _conversations.removeWhere((c) => c.userId == userId));
              await MessageService.instance.deleteConversation(userId);
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
                  _markConversationRead(conv.userId);
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

  Widget _buildBottomSelectionBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      // Float it safely above the bottom navigation bar
      bottom:
          _isSelectionMode ? MediaQuery.of(context).padding.bottom + 100 : -100,
      left: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: _dark,
          borderRadius:
              BorderRadius.circular(32), // Elegant floating pill shape
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10))
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
                          : const Color(0xFFEF4444)),
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
                    child: _isSelectionMode
                        ? _buildSelectionHeader()
                        : _buildNormalHeader(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildConversationsList()),
              ],
            ),
            _buildBottomSelectionBar(),
          ],
        ),
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
    final bool hasUnread = unread > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected
            ? _green.withOpacity(0.05)
            : Colors.transparent, // Highlight background if selected
        padding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 8), // Flat list padding
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isSelected
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsRegular.circle,
                  color: isSelected ? _green : _grey,
                  size: 24,
                ),
              )
            else if (hasUnread)
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 6,
                height: 6,
                decoration:
                    const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: _dark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w500,
                          color: hasUnread ? _green : _grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                            color: hasUnread ? _dark : _grey,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final Widget avatarWidget = avatarUrl != null &&
            avatarUrl!.trim().isNotEmpty
        ? AppSession.buildAvatar(avatarUrl,
            width: 56, height: 56, fit: BoxFit.cover)
        : Container(
            color: _grey.withOpacity(0.1),
            child:
                const Icon(PhosphorIconsRegular.user, color: _grey, size: 24),
          );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _grey.withOpacity(0.1)),
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
                color: _green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
