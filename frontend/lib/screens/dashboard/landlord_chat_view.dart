import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/fcm_service.dart';
import 'package:uuid/uuid.dart';
import 'package:property_app/models/communication_models.dart';
import 'package:property_app/widgets/property_image.dart';

const Color _landlordPrimary = Color(0xFF059669);

// ─── Main Widget ──────────────────────────────────────────────────────────────

class LandlordChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final String userId;
  final String name;
  final String? avatar;

  const LandlordChatView({
    super.key,
    required this.onBack,
    required this.userId,
    required this.name,
    this.avatar,
    this.onCall,
  });

  @override
  State<LandlordChatView> createState() => _LandlordChatViewState();
}

class _LandlordChatViewState extends State<LandlordChatView>
    with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _pageController;
  late final AnimationController _listController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  StreamSubscription? _socketSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _seenSubscription;
  StreamSubscription? _fcmSubscription;

  bool _isTyping = false;
  bool _isOtherTyping = false;
  bool _isLoading = true;
  Timer? _typingDebounce;

  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _pageController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _pageController, curve: Curves.easeIn);

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

    _typingSubscription = SocketService.instance.typing.listen((data) {
      if (data['userId'] == widget.userId) {
        setState(() => _isOtherTyping = data['isTyping'] == true);
      }
    });

    _seenSubscription = SocketService.instance.seen.listen((data) {
      // Update local message status to seen
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          if (_messages[i].sender == ChatSender.me &&
              _messages[i].status != MessageStatus.sent) {
            _messages[i] = _messages[i].copyWith(status: MessageStatus.sent);
          }
        }
      });
    });

    // Listen for FCM messages while in the chat to update UI if socket is slow
    _fcmSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['senderId'] == widget.userId) {
        final text = message.notification?.body ?? '';
        final ts = DateTime.now().millisecondsSinceEpoch;

        // The logic inside _addMessage automatically handles de-duplication via msg.id
        final fcmMsgId = message.messageId ?? 'fcm_$ts';

        if (!_messages.any((m) => m.id == fcmMsgId)) {
          _addMessage(ChatMessage(
            id: fcmMsgId,
            sender: ChatSender.them,
            text: text,
            time: _formatTime(DateTime.now()),
          ));
        }
      }
    });

    // Only handle messages FROM the other person — our own are added optimistically
    _socketSubscription = SocketService.instance.messages.listen((msg) {
      if (msg.from != widget.userId) return;

      final socketId = msg.id.trim();
      final socketText = msg.text.trim();
      final socketTs = msg.ts;

      final alreadyById =
          socketId.isNotEmpty && _messages.any((m) => m.id == socketId);
      if (alreadyById) return;

      final alreadyByFingerprint = _messages.any((m) =>
          m.text.trim() == socketText &&
          (m.time == 'Now' ||
              m.time ==
                  _formatTime(DateTime.fromMillisecondsSinceEpoch(socketTs))));
      if (alreadyByFingerprint) return;

      _addMessage(ChatMessage(
        id: socketId.isNotEmpty
            ? socketId
            : 'socket_${socketTs}_${socketText.hashCode}',
        sender: ChatSender.them,
        text: msg.text,
        time: _formatTime(DateTime.fromMillisecondsSinceEpoch(socketTs)),
      ));
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _fcmSubscription?.cancel();
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
    if (_messages.any((m) => m.id == msg.id)) return;

    setState(() {
      _messages.add(msg);
    });
    _scrollToBottom();
  }

  Future<void> _fetchMessages() async {
    try {
      final messages =
          await MessageService.instance.fetchConversation(widget.userId);
      if (!mounted) return;

      final currentUserId = AppSession.currentUserId ?? '';

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        for (final msg in messages) {
          final chatMsg = ChatMessage(
            id: msg.id,
            sender: msg.fromUserId == currentUserId
                ? ChatSender.me
                : ChatSender.them,
            text: msg.text,
            time: _formatTime(msg.createdAt),
          );

          if (!_messages.any((m) => m.id == chatMsg.id)) {
            _messages.add(chatMsg);
          }
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (err) {
      setState(() => _isLoading = false);
      debugPrint('Failed to fetch messages: $err');
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    final messageId = const Uuid().v4();
    // Optimistic local append
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
      debugPrint('Failed to save message: $err');
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.05).clamp(0.0, 1.0);
    final double end = (start + 0.6).clamp(0.0, 1.0);
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
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildChatArea(),
              ),
              _buildInputArea(context),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

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
          GestureDetector(
            onTap: widget.onBack,
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
          ),
          const SizedBox(width: 16),
          ClipOval(
            child: (widget.avatar != null && widget.avatar!.trim().isNotEmpty)
                ? AppSession.buildAvatar(
                    widget.avatar,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
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
                            : const Color(0xFF10B981),
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
                      style: GoogleFonts.poppins(
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
          GestureDetector(
            onTap: widget.onCall,
            child: Icon(PhosphorIcons.phone(PhosphorIconsStyle.fill), color: Colors.black, size: 26),
          ),
        ],
      ),
    );
  }

  // ─── Chat Area ───────────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet.\nSay hello!',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: const Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
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
        final Widget bubble = msg.sender == ChatSender.me
            ? _MyBubble(
                message: msg,
                onRetry: () => _retryMessage(msg),
              )
            : _TheirBubble(message: msg, avatar: widget.avatar);
        return _buildStaggered(
          index: index,
          child: Padding(
              padding: const EdgeInsets.only(bottom: 24), child: bubble),
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
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF))),
        ),
      ),
    );
  }

  // ─── Minimalistic Input Area ──────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {}, // Attachments Action
            child: Icon(
              PhosphorIcons.plusCircle(PhosphorIconsStyle.fill),
              color: const Color(0xFF9CA3AF),
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          
          // Clean Pill Search-Bar-style Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6), 
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
                        color: Colors.black,
                      ),
                      // Absolutely no native fills or boundaries
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color(0xFF9CA3AF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  if (!_isTyping)
                    GestureDetector(
                      onTap: () {}, // Camera Action
                      child: Icon(
                        PhosphorIcons.camera(), 
                        color: const Color(0xFF9CA3AF), 
                        size: 22
                      ),
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
                        color: _landlordPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
                : GestureDetector(
                    key: const ValueKey('mic'),
                    onTap: () {}, // Mic Action
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.microphone(),
                        color: const Color(0xFF9CA3AF), 
                        size: 22
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubble Widgets ───────────────────────────────────────────────────────────

class _TheirBubble extends StatelessWidget {
  final ChatMessage message;
  final String? avatar;
  const _TheirBubble({required this.message, required this.avatar});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: (avatar != null && avatar!.trim().isNotEmpty)
              ? AppSession.buildAvatar(
                  avatar,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
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
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                        height: 1.4)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(message.time,
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
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
        // Mock seen state indicator
        const isSeen = false; 
        return Icon(Icons.done_all,
            size: 16, color: isSeen ? const Color(0xFF4ADE80) : Colors.white70);
      case MessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child:
                Icon(Icons.error_outline, size: 16, color: Color(0xFFFCA5A5)),
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
        const SizedBox(width: 60),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _landlordPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                    color: _landlordPrimary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        height: 1.4)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message.time,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.8))),
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