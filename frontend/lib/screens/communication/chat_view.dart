import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/services/message_service.dart';
import 'package:uuid/uuid.dart';
import 'package:property_app/models/communication_models.dart';

const Color _primary = Color(0xFF3F37C9);

// ─── Main Widget ──────────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final String userId;
  final String name;
  final String avatar;

  const ChatView({
    super.key,
    required this.onBack,
    required this.userId,
    required this.name,
    required this.avatar,
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
  bool _isTyping = false;
  bool _isOtherTyping = false;
  Timer? _typingDebounce;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
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

    // Fetch messages from backend
    _fetchMessages();

    // State action: mark messages from this conversation partner as read
    // so unread badges/conversation list state stay consistent.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await MessageService.instance.markAsRead([widget.userId]);
        // No local badge state exists here; MessagesViewScreen reloads on return.
      } catch (_) {
        // Ignore read-tracking failures to avoid breaking chat UI.
      }
    });

    // Listen to socket messages
    _socketSubscription = SocketService.instance.messages.listen((msg) {
      // Debug: helps confirm whether the same socket payload is received multiple times.
      // ignore: avoid_print
      print(
          'socket message recv: id=${msg.id} from=${msg.from} to=${msg.to} ts=${msg.ts} text=${msg.text}');

      // Only handle messages FROM the person we are chatting with.
      // For sender, we rely on optimistic UI + HTTP reconciliation.
      if (msg.from != widget.userId) return;

      final socketId = msg.id.trim();
      final socketText = msg.text.trim();
      final socketTime = msg.ts;

      // Robust dedupe: prefer DB id, but also guard against empty/missing id
      // and against duplicate events.
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
      if (data['userId'] == widget.userId) {
        setState(() => _isOtherTyping = data['isTyping'] == true);
      }
    });

    _seenSubscription = SocketService.instance.seen.listen((data) {
      // Logic to update local message status to seen
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
    _pageController.dispose();
    _listController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleTypingStatus() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    SocketService.instance.sendTyping(to: widget.userId, isTyping: true);

    _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
      SocketService.instance.sendTyping(to: widget.userId, isTyping: false);
    });
  }

  void _addMessage(ChatMessage msg) {
    // Global ID check to prevent duplicates
    if (_messages.any((m) => m.id == msg.id)) return;

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
    // Append message locally immediately for UX
    _addMessage(ChatMessage(
      id: messageId,
      sender: ChatSender.me,
      text: text,
      time: 'Now',
      status: MessageStatus.sending,
    ));

    // Send over socket
    SocketService.instance.sendMessage(to: widget.userId, text: text);

    _performSave(messageId, text);
  }

  Future<void> _performSave(String messageId, String text) async {
    try {
      final realId = await MessageService.instance
          .saveMessage(toUserId: widget.userId, text: text);
      if (!mounted) return;
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(
            id: realId,
            status: MessageStatus.sent,
          );
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
      print('Failed to save message: $err');
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
      final messages =
          await MessageService.instance.fetchConversation(widget.userId);
      if (!mounted) return;

      // Ensure messages are sorted by creation date before adding to the UI list
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        for (final msg in messages) {
          final chatMsg = ChatMessage(
            id: msg.id, // Use actual DB ID
            sender: msg.fromUserId == widget.userId
                ? ChatSender.them
                : ChatSender.me,
            text: msg.text,
            time: _formatTime(msg.createdAt.millisecondsSinceEpoch),
          );

          if (!_messages.any((m) => m.id == chatMsg.id)) {
            _messages.add(chatMsg);
          }
        }
      });
      _scrollToBottom();
    } catch (err) {
      setState(() {
      });
      // ignore: avoid_print
      print('Failed to fetch messages: $err');
    }
  }

  void _scrollToBottom() {
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
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.15).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _listController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation),
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
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildChatArea()),
              _buildInputArea(context),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 20,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: widget.onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          // Avatar
          ClipOval(
            child: buildPropertyImage(
              widget.avatar,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isOtherTyping
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        boxShadow: _isOtherTyping
                            ? [
                                BoxShadow(
                                    color: const Color(0xFF3B82F6)
                                        .withOpacity(0.4),
                                    blurRadius: 4,
                                    spreadRadius: 1)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOtherTyping ? 'typing...' : 'Online',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isOtherTyping
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Call button
          GestureDetector(
            onTap: widget.onCall,
            child: const Icon(Icons.call, color: Colors.black, size: 28),
          ),
        ],
      ),
    );
  }

  // ─── Chat Area ──────────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: _messages.length + 1, // +1 for date divider
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildStaggered(
            index: index,
            child: _buildDateDivider('Today'),
          );
        }

        final msg = _messages[index - 1];
        final Widget bubble = msg.sender == ChatSender.me
            ? _MyBubble(
                message: msg,
                onRetry: () => _retryMessage(msg),
              )
            : _TheirBubble(message: msg, avatar: widget.avatar);

        return _buildStaggered(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: bubble,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Area ─────────────────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isTyping == false) _buildQuickReplies(),
          _buildActualInput(context),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final replies = ['Is it available?', 'When can I view?', 'Can we talk?'];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: replies
            .map((r) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(r,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _primary)),
                    onPressed: () {
                      _msgController.text = r;
                      _sendMessage();
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActualInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {}, // Attachments
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF9CA3AF),
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _msgController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Type a message..',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          // Action Icons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.sentiment_satisfied_alt_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: child,
                ),
                child: _isTyping
                    ? GestureDetector(
                        key: const ValueKey('send'),
                        onTap: _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('camera'),
                        onTap: () {},
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF9CA3AF),
                          size: 28,
                        ),
                      ),
              ),
            ],
          ),
        ],
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
          child: buildPropertyImage(
            avatar,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              border: Border.all(color: const Color(0xFFF3F4F6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
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
        // The double-tick color logic
        final isSeen = false; // Mock seen state
        return Icon(Icons.done_all,
            size: 16, color: isSeen ? const Color(0xFF4ADE80) : Colors.white70);
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  color: _primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
