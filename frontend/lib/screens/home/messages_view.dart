import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/api_result.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme

// ─── Local UI model ───────────────────────────────────────────────────────────
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

enum _MessageFilter { all, unread, landlords, archived }

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

class _MessagesViewScreenState extends State<MessagesViewScreen> {
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('messagesSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          title: 'Your conversations live here',
          imagePath: 'assets/images/message_onboarding.png',
          subtitle: 'Communicate with hosts seamlessly.',
          ctaText: 'Got it',
        ).then((_) => OnboardingPrefs.markAsSeen('messagesSeen'));
      }
    });

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
        _loadConversations();
      }
    });

    _presenceSubscription = SocketService.instance.presence.listen((data) {
      final userId = data['userId']?.toString();
      final isOnline = data['online'] == true;
      final idx = _chats.indexWhere((c) => c.id == userId);
      if (idx != -1) {
        if (mounted) setState(() => _chats[idx].online = isOnline);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiResult.mapError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _markConversationRead(String userId) async {
    final index = _chats.indexWhere((chat) => chat.id == userId);
    if (index != -1) {
      setState(() {
        _chats[index].unread = 0;
      });
    }

    try {
      await MessageService.instance.markAsRead([userId]);
    } catch (_) {
      // Keep the optimistic UI state and refresh on next load.
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
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
      _loadConversations();
    }
  }

  Future<void> _markSelectedAsRead() async {
    try {
      final idsToMark = _selectedIds.toList();
      await MessageService.instance.markAsRead(idsToMark);

      setState(() {
        for (final c in _chats) {
          if (idsToMark.contains(c.id)) c.unread = 0;
        }
        _exitSelectionMode();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiResult.mapError(e))));
    }
  }

  // ── Build UI ────────────────────────────────────────────────────────────────

  Widget _buildNormalHeader() {
    return Row(
      key: const ValueKey('normalHeader'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Messages',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: _dark,
            letterSpacing: -1.0,
          ),
        ),
        PopupMenuButton<_MessageFilter>(
          icon: const Icon(PhosphorIconsRegular.dotsThreeVertical,
              color: _dark, size: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          elevation: 4,
          onSelected: (filter) => setState(() => _currentFilter = filter),
          itemBuilder: (context) => _MessageFilter.values.map((filter) {
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
                    color: isSelected ? _tenantPrimary : _grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? _tenantPrimary : _dark,
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
              child: const Icon(PhosphorIconsRegular.x, color: _dark, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              '${_selectedIds.length} Selected',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _selectAll(_chats
              .where((c) => c.name.toLowerCase().contains(_searchQuery))
              .toList()),
          child: Text(
            allSelected ? 'Unselect All' : 'Select All',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _tenantPrimary,
            ),
          ),
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
              style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w500, color: _dark),
              decoration: InputDecoration(
                hintText: 'Search Messages',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w400, color: _grey),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 160),
      itemCount: 8,
      separatorBuilder: (_, __) =>
          Divider(color: _grey.withOpacity(0.1), height: 1, indent: 96),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
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
          if (_searchQuery.isEmpty && _suggestedContacts.isNotEmpty) ...[
            Text(
              'Start a conversation',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
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
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _grey.withOpacity(0.2))),
                            child: ClipOval(
                                child: AppSession.buildAvatar(contact.avatarUrl,
                                    width: 60, height: 60, fit: BoxFit.cover)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            contact.name.split(' ')[0],
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _dark),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const Icon(PhosphorIconsRegular.chatTeardropSlash,
                size: 64, color: _grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No messages yet' : 'No messages found',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Your conversations will appear here.'
                  : 'Try adjusting your search query.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildBottomSelectionBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom:
          _isSelectionMode ? MediaQuery.of(context).padding.bottom + 16 : -100,
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
                offset: const Offset(0, 10))
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
              behavior: HitTestBehavior.opaque,
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
    Iterable<_ChatItem> filtered =
        _chats.where((c) => c.name.toLowerCase().contains(_searchQuery));
    if (_currentFilter == _MessageFilter.unread) {
      filtered = filtered.where((c) => c.unread > 0);
    } else if (_currentFilter == _MessageFilter.archived) {
      filtered = filtered.where((c) => false);
    }
    final displayList = filtered.toList();

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
                        ? _buildSelectionHeader(displayList.length)
                        : _buildNormalHeader(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? _buildShimmerLoading()
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(PhosphorIconsRegular.warningCircle,
                                      color: Colors.redAccent, size: 48),
                                  const SizedBox(height: 16),
                                  Text(_errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                          color: _dark,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  TextButton(
                                      onPressed: _loadConversations,
                                      child: Text('Retry',
                                          style: GoogleFonts.poppins(
                                              color: _tenantPrimary))),
                                ],
                              ),
                            )
                          : displayList.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  color: _tenantPrimary,
                                  backgroundColor: _surface,
                                  onRefresh: _loadConversations,
                                  child: ListView.separated(
                                    physics: const BouncingScrollPhysics(
                                        parent:
                                            AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.fromLTRB(
                                        0,
                                        8,
                                        0,
                                        MediaQuery.of(context).padding.bottom +
                                            120),
                                    itemCount: displayList.length,
                                    separatorBuilder: (_, __) => Divider(
                                        color: _grey.withOpacity(0.15),
                                        height: 1,
                                        indent: 96),
                                    itemBuilder: (context, i) {
                                      final chat = displayList[i];
                                      final isSelected =
                                          _selectedIds.contains(chat.id);

                                      return Dismissible(
                                        key: ValueKey(chat.id),
                                        direction: DismissDirection
                                            .endToStart, // Swipe left to delete
                                        background: Container(
                                          color: const Color(0xFFEF4444),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24),
                                          child: const Icon(
                                              PhosphorIconsRegular.trash,
                                              color: Colors.white,
                                              size: 28),
                                        ),
                                        onDismissed: (_) async {
                                          _selectedIds = {chat.id};
                                          await _deleteSelected();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        '${chat.name} deleted'),
                                                    behavior: SnackBarBehavior
                                                        .floating));
                                          }
                                        },
                                        child: _ChatTile(
                                          chat: chat,
                                          isSelectionMode: _isSelectionMode,
                                          isSelected: isSelected,
                                          onTap: () {
                                            if (_isSelectionMode) {
                                              _toggleChatSelection(chat.id);
                                            } else {
                                              _markConversationRead(chat.id);
                                              widget.onSelectChat(chat.id,
                                                  chat.name, chat.avatarUrl);
                                            }
                                          },
                                          onLongPress: () {
                                            if (!_isSelectionMode)
                                              _enterSelectionMode(chat.id);
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
            _buildBottomSelectionBar(),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool hasUnread = chat.unread > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isSelected
            ? _tenantPrimary.withOpacity(0.05)
            : Colors.transparent, // Highlight background if selected
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 12), // Edge-to-Edge feel
        child: Row(
          children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isSelected
                      ? PhosphorIconsFill.checkCircle
                      : PhosphorIconsRegular.circle,
                  color: isSelected ? _tenantPrimary : _grey,
                  size: 24,
                ),
              )
            else if (hasUnread)
              Container(
                margin: const EdgeInsets.only(right: 12),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: _tenantPrimary, shape: BoxShape.circle),
              ),

            // Avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _grey.withOpacity(0.1))),
                  child: ClipOval(
                      child: AppSession.buildAvatar(chat.avatarUrl,
                          width: 56, height: 56, fit: BoxFit.cover)),
                ),
                if (chat.online)
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
                      Expanded(
                        child: Text(
                          chat.name,
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
                        chat.time,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w500,
                          color: hasUnread ? _tenantPrimary : _grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.msg,
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
                            color: _tenantPrimary,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            chat.unread > 99 ? '99+' : chat.unread.toString(),
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
}
