import 'package:flutter/material.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/services/message_service.dart';

const Color _primary = Color(0xFF3F37C9);

// ─── Data model ───────────────────────────────────────────────────────────────

enum _Sender { me, them }

class _ChatMessage {
  final _Sender sender;
  final String text;
  final String time;
  const _ChatMessage({
    required this.sender,
    required this.text,
    required this.time,
  });
}

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

  bool _isTyping = false;
  bool _isLoading = true;

  final List<_ChatMessage> _messages = [];

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
      setState(() {
        _isTyping = _msgController.text.trim().isNotEmpty;
      });
    });

    _pageController.forward().then((_) => _listController.forward());

    // Fetch messages from backend
    _fetchMessages();

    // Listen to socket messages
    SocketService.instance.messages.listen((msg) {
      if (msg.from == widget.userId || msg.to == widget.userId) {
        final isMe = msg.from == msg.from; // From current user
        setState(() {
          _messages.add(_ChatMessage(
            sender: isMe ? _Sender.me : _Sender.them,
            text: msg.text,
            time: _formatTime(msg.ts),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _listController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    // Append message locally immediately for UX
    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.me, text: text, time: 'Now'));
    });
    _scrollToBottom();

    // Send over socket
    SocketService.instance.sendMessage(to: widget.userId, text: text);

    // Save to backend via REST API
    MessageService.instance
        .saveMessage(toUserId: widget.userId, text: text)
        .catchError((err) {
      // Handle error silently or show toast
      // ignore: avoid_print
      print('Failed to save message: $err');
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final messages =
          await MessageService.instance.fetchConversation(widget.userId);
      setState(() {
        _messages.clear();
        for (final msg in messages) {
          _messages.add(_ChatMessage(
            sender:
                msg.fromUserId == msg.fromUserId ? _Sender.me : _Sender.them,
            text: msg.text,
            time: _formatTime(msg.createdAt.millisecondsSinceEpoch),
          ));
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (err) {
      setState(() {
        _isLoading = false;
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
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), // Green dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
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
        final Widget bubble = msg.sender == _Sender.me
            ? _MyBubble(message: msg)
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
          // Text input
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
  final _ChatMessage message;
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
  final _ChatMessage message;

  const _MyBubble({required this.message});

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
                  child: Text(
                    message.time,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
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
