import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/widgets/property_conversation_header.dart';
import 'package:uuid/uuid.dart';
import 'package:property_app/models/communication_models.dart';
import 'package:property_app/utils/presence_format.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _primary = Color(0xFF3F37C9); // Tenant Blue Theme

// ─── Main Widget ──────────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final String userId;
  final String? conversationId;
  final ConversationModel? initialConversation;
  final String name;
  final String avatar;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const ChatView({
    super.key,
    required this.onBack,
    required this.userId,
    this.conversationId,
    this.initialConversation,
    required this.name,
    required this.avatar,
    this.isOnline = false,
    this.lastSeenAt,
    this.onCall,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _pageController;
  late final AnimationController _listController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  StreamSubscription? _socketSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _seenSubscription;
  StreamSubscription? _presenceSubscription;

  bool _isTyping = false;
  bool _isOtherTyping = false;
  late bool _isOtherOnline;
  DateTime? _lastSeenAt;
  Timer? _typingDebounce;
  Timer? _presenceRefreshTimer;

  final List<ChatMessage> _messages = [];
  late String _peerUserId;
  ConversationModel? _conversation;

  String? get _activeConversationId =>
      widget.conversationId ?? _conversation?.conversationId;

  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _peerUserId = widget.userId;
    _conversation = widget.initialConversation;
    _isOtherOnline = widget.isOnline;
    _lastSeenAt = widget.lastSeenAt;
    final latestPresence = _peerUserId.isEmpty
        ? null
        : SocketService.instance.latestPresenceFor(_peerUserId);
    if (latestPresence != null) {
      _isOtherOnline = latestPresence['online'] == true;
      _lastSeenAt = DateTime.tryParse(
        latestPresence['lastSeenAt']?.toString() ?? '',
      );
    }
    _presenceRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    // Page Entrance Animation
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _pageController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _pageController, curve: Curves.easeIn);

    // List Staggered Animation
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _msgController.addListener(() {
      _handleTypingStatus();
      setState(() {
        _isTyping = _msgController.text.trim().isNotEmpty;
      });
    });

    _pageController.forward().then((_) => _listController.forward());

    _fetchMessages();

    // Listen to socket messages
    _socketSubscription = SocketService.instance.messages.listen((msg) {
      if (msg.from != _peerUserId ||
          (_activeConversationId != null &&
              msg.conversationId != _activeConversationId)) return;

      final socketId = msg.id.trim();
      final socketText = msg.text.trim();
      final socketTime = msg.ts;

      final alreadyById =
          socketId.isNotEmpty && _messages.any((m) => m.id == socketId);
      if (alreadyById) return;

      final alreadyByFingerprint = _messages.any((m) =>
          m.text.trim() == socketText &&
          (m.time == 'Now' || m.time == _formatTime(socketTime)));
      if (alreadyByFingerprint) return;

      _addMessage(ChatMessage(
        id: socketId.isNotEmpty
            ? socketId
            : 'socket_${socketTime}_${socketText.hashCode}',
        sender: ChatSender.them,
        text: msg.text,
        time: _formatTime(socketTime),
      ));
    });

    _typingSubscription = SocketService.instance.typing.listen((data) {
      if (data['userId'] == _peerUserId) {
        if (mounted) setState(() => _isOtherTyping = data['isTyping'] == true);
      }
    });

    _presenceSubscription = SocketService.instance.presence.listen((data) {
      if (data['userId']?.toString() != _peerUserId || !mounted) return;
      setState(() {
        _isOtherOnline = data['online'] == true;
        _lastSeenAt = DateTime.tryParse(data['lastSeenAt']?.toString() ?? '');
      });
    });

    _seenSubscription = SocketService.instance.seen.listen((data) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].sender == ChatSender.me &&
              _messages[i].status != MessageStatus.sent) {
            _messages[i] = _messages[i].copyWith(status: MessageStatus.sent);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _typingSubscription?.cancel();
    _seenSubscription?.cancel();
    _presenceSubscription?.cancel();
    _typingDebounce?.cancel();
    _presenceRefreshTimer?.cancel();
    _pageController.dispose();
    _listController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTypingStatus() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    if (_peerUserId.isEmpty) return;
    SocketService.instance.sendTyping(to: _peerUserId, isTyping: true);

    _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (_peerUserId.isNotEmpty) {
        SocketService.instance.sendTyping(to: _peerUserId, isTyping: false);
      }
    });
  }

  void _addMessage(ChatMessage msg) {
    if (_messages.any((m) => m.id == msg.id)) return;

    if (!mounted) return;
    setState(() {
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final messageId = const Uuid().v4();
    _addMessage(ChatMessage(
      id: messageId,
      sender: ChatSender.me,
      text: text,
      time: 'Now',
      status: MessageStatus.sending,
    ));

    _performSave(messageId, text);
  }

  Future<void> _performSave(String messageId, String text) async {
    try {
      final savedMessage = await MessageService.instance.saveMessage(
        toUserId: _peerUserId,
        text: text,
        conversationId: _activeConversationId,
      );
      if (!mounted) return;
      if (_conversation?.conversationId == null &&
          savedMessage.conversationId != null) {
        _conversation = _conversation?.copyWith(
              conversationId: savedMessage.conversationId,
            ) ??
            ConversationModel(
              conversationId: savedMessage.conversationId,
              userId: _peerUserId,
              userName: widget.name,
              userAvatar: widget.avatar,
            );
      }
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx]
              .copyWith(id: savedMessage.id, status: MessageStatus.sent);
        });
      }
    } catch (err) {
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        setState(() {
          _messages[idx] =
              _messages[idx].copyWith(status: MessageStatus.failed);
        });
      }
    }
  }

  void _retryMessage(ChatMessage msg) {
    if (msg.status != MessageStatus.failed) return;
    setState(() {
      final idx = _messages.indexOf(msg);
      if (idx != -1) {
        _messages[idx] = msg.copyWith(status: MessageStatus.sending);
      }
    });
    _performSave(msg.id, msg.text);
  }

  Future<void> _fetchMessages() async {
    try {
      final conversationId = _activeConversationId;
      final List<MessageModel> messages;
      if (conversationId != null && conversationId.isNotEmpty) {
        final history =
            await MessageService.instance.fetchConversationById(conversationId);
        _conversation = history.conversation;
        _peerUserId = history.conversation.userId;
        messages = history.messages;
      } else {
        final history =
            await MessageService.instance.fetchGeneralConversationHistory(
          _peerUserId,
          userName: widget.name,
          userAvatar: widget.avatar,
        );
        _conversation = history.conversation;
        messages = history.messages;
      }
      if (!mounted) return;

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        for (final msg in messages) {
          final chatMsg = ChatMessage(
            id: msg.id,
            sender: msg.fromUserId == (AppSession.currentUserId ?? '')
                ? ChatSender.me
                : ChatSender.them,
            text: msg.text,
            time: _formatTime(msg.createdAt.millisecondsSinceEpoch),
          );

          if (!_messages.any((m) => m.id == chatMsg.id)) {
            _messages.add(chatMsg);
          }
        }
      });
      await MessageService.instance.markAsRead(
        _activeConversationId == null ? [_peerUserId] : const [],
        conversationIds:
            _activeConversationId == null ? const [] : [_activeConversationId!],
      );
      _scrollToBottom();
    } catch (err) {
      setState(() {});
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        final isNearBottom = (pos.maxScrollExtent - pos.pixels) <= 150;
        if (force || isNearBottom) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }
  void _oldScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _toggleSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.add(id);
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _copySelected() {
    final selectedMsgs = _messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .map((m) => m.text)
        .join('\n');
    if (selectedMsgs.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: selectedMsgs));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Copied to clipboard', style: GoogleFonts.poppins())));
    }
    _exitSelectionMode();
  }

  void _deleteSelected() {
    setState(() {
      _messages.removeWhere((m) => _selectedMessageIds.contains(m.id));
      _selectedMessageIds.clear();
      _isSelectionMode = false;
    });
    // Optional: Call MessageService to delete remotely if supported by your API
  }

  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.05).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _listController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isSelectionMode
                          ? _buildSelectionHeader()
                          : _buildNormalHeader(),
                    ),
                    if (_conversation?.property != null)
                      PropertyConversationHeader(
                          property: _conversation!.property!),
                    Expanded(child: _buildChatArea()),
                    // If not selecting, show normal input area. We use a transparent box to keep scroll positioning identical when hidden
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _isSelectionMode
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: _buildInputArea(context),
                      secondChild: SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 80),
                    ),
                  ],
                ),
                _buildBottomSelectionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Headers ────────────────────────────────────────────────────────────────

  Widget _buildNormalHeader() {
    final displayName = _conversation?.userName ?? widget.name;
    final displayAvatar = _conversation?.userAvatar ?? widget.avatar;
    return Container(
      key: const ValueKey('normal_header'),
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(PhosphorIconsRegular.caretLeft,
                size: 28, color: _dark),
          ),
          const SizedBox(width: 16),
          ClipOval(
            child: AppSession.buildAvatar(
              displayAvatar,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isOtherTyping
                            ? _primary
                            : _isOtherOnline
                                ? const Color(0xFF10B981)
                                : _grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOtherTyping
                          ? 'typing...'
                          : presenceLabel(
                              online: _isOtherOnline,
                              lastSeenAt: _lastSeenAt,
                            ),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isOtherTyping
                            ? _primary
                            : _isOtherOnline
                                ? const Color(0xFF10B981)
                                : _grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onCall,
            child:
                const Icon(PhosphorIconsRegular.phone, color: _dark, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      key: const ValueKey('selection_header'),
      padding: const EdgeInsets.fromLTRB(20, 24, 24, 24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitSelectionMode,
            behavior: HitTestBehavior.opaque,
            child: const Icon(PhosphorIconsRegular.x, size: 28, color: _dark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${_selectedMessageIds.length} Selected',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chat Area ──────────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.chatCircleText,
                size: 56, color: _grey),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello and start the conversation!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStaggered(
              index: index, child: _buildDateDivider('Today'));
        }

        final msg = _messages[index - 1];
        final isSelected = _selectedMessageIds.contains(msg.id);

        final Widget bubble = msg.sender == ChatSender.me
            ? _MyBubble(message: msg, onRetry: () => _retryMessage(msg))
            : _TheirBubble(
                message: msg,
                avatar: _conversation?.userAvatar ?? widget.avatar,
              );

        return _buildStaggered(
          index: index,
          child: GestureDetector(
            onTap: () {
              if (_isSelectionMode) _toggleItemSelection(msg.id);
            },
            onLongPress: () {
              if (!_isSelectionMode) _toggleSelectionMode(msg.id);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              // Slight tint when selected
              decoration: BoxDecoration(
                color: isSelected
                    ? _primary.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: Icon(
                        isSelected
                            ? PhosphorIconsFill.checkCircle
                            : PhosphorIconsRegular.circle,
                        color: isSelected ? _primary : _grey,
                        size: 24,
                      ),
                    ),
                  Expanded(child: bubble),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _grey,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Area ─────────────────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {}, // Attachments Action
            child: const Icon(PhosphorIconsRegular.plusCircle,
                color: _grey, size: 28),
          ),
          const SizedBox(width: 12),

          // Clean Pill Input-Bar
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _dark,
                      ),
                      // Absolutely no native fills or boundaries
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: _grey,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  if (!_isTyping)
                    GestureDetector(
                      onTap: () {}, // Camera Action
                      child: const Icon(PhosphorIconsRegular.camera,
                          color: _grey, size: 22),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send / Mic Button Switcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isTyping
                ? GestureDetector(
                    key: const ValueKey('send'),
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: _primary, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.paperPlaneRight,
                          color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: () {}, // Mic Action
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _grey.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsRegular.microphone,
                          color: _grey, size: 22),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Selection Action Bar ───────────────────────────────────────────────────

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
              onTap: _selectedMessageIds.isEmpty ? null : _copySelected,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.copy,
                      color: _selectedMessageIds.isEmpty
                          ? _grey.withOpacity(0.5)
                          : Colors.white),
                  const SizedBox(height: 4),
                  Text('Copy',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedMessageIds.isEmpty
                              ? _grey.withOpacity(0.5)
                              : Colors.white)),
                ],
              ),
            ),
            Container(width: 1, height: 30, color: _grey.withOpacity(0.3)),
            GestureDetector(
              onTap: _selectedMessageIds.isEmpty ? null : _deleteSelected,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.trash,
                      color: _selectedMessageIds.isEmpty
                          ? _grey.withOpacity(0.5)
                          : const Color(0xFFEF4444)),
                  const SizedBox(height: 4),
                  Text('Delete',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _selectedMessageIds.isEmpty
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
}

// ─── Bubble Widgets ───────────────────────────────────────────────────────────

class _TheirBubble extends StatelessWidget {
  final ChatMessage message;
  final String avatar;

  const _TheirBubble({required this.message, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: AppSession.buildAvatar(
            avatar,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              border: Border.all(color: _grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: _dark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.time,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48), // Padding on right to constrain width
      ],
    );
  }
}

class _MyBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const _MyBubble({required this.message, this.onRetry});

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sent:
        const isSeen = false; // Mock seen state
        return const Icon(
          isSeen ? PhosphorIconsRegular.checks : PhosphorIconsRegular.check,
          size: 14,
          color: Colors.white70,
        );
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(PhosphorIconsRegular.warningCircle,
                size: 16, color: Color(0xFFFCA5A5)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 60), // Padding on left to constrain width
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildStatusIcon(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
