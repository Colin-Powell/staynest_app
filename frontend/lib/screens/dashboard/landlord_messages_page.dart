import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/message_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Color _landlordPrimary = Color(0xFF059669);
const Color _textDark = Color(0xFF111827);
const Color _textLight = Color(0xFF9CA3AF);

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

  List<ConversationModel> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
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
    super.dispose();
  }

  List<ConversationModel> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations
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

    return RefreshIndicator(
      color: _landlordPrimary,
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conv = _filteredConversations[index];
          return _ConversationTile(
            name: conv.userName,
            avatarUrl: conv.userAvatar,
            lastMessage: conv.lastMessage ?? 'No messages yet',
            time: _formatTime(conv.lastMessageAt),
            unread: 0, // unread count not in ConversationModel yet
            isOnline: false,
            onTap: () {
              widget.onChatOpen();
              setState(() => _selectedConversation = conv);
            },
          );
        },
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
        avatarUrl: conv.userAvatar,
        otherUserId: conv.userId,
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
                child: Text(
                  'Messages',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
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
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.isOnline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
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
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: _landlordPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread.toString(),
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

// ─── Data model ──────────────────────────────────────────────────────────────

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

// ─── Chat View ───────────────────────────────────────────────────────────────

class LandlordChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final String name;
  final String? avatarUrl;

  /// The other participant's userId — used for fetch & send
  final String otherUserId;

  const LandlordChatView({
    super.key,
    required this.onBack,
    required this.name,
    required this.otherUserId,
    this.avatarUrl,
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

  bool _isTyping = false;
  bool _isLoadingMessages = true;
  bool _isSending = false;
  String? _loadError;

  final List<_ChatMessage> _messages = [];

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
    _fadeAnim =
        CurvedAnimation(parent: _pageController, curve: Curves.easeIn);

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _msgController.addListener(() {
      setState(() => _isTyping = _msgController.text.trim().isNotEmpty);
    });

    _pageController
        .forward()
        .then((_) => _listController.forward());

    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
      _loadError = null;
    });

    try {
      final fetched = await MessageService.instance
          .fetchConversation(widget.otherUserId);

      final currentUserId = AppSession.currentUserId;

      setState(() {
        _messages.clear();
        _messages.addAll(fetched.map((m) => _ChatMessage(
              sender:
                  m.fromUserId == currentUserId ? _Sender.me : _Sender.them,
              text: m.text,
              time: _formatTime(m.createdAt),
            )));
        _isLoadingMessages = false;
      });

      _scrollToBottom(immediate: true);
    } catch (e) {
      setState(() {
        _loadError = 'Could not load messages. Tap to retry.';
        _isLoadingMessages = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _listController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _scrollToBottom({bool immediate = false}) {
    final delay = immediate ? 0 : 300;
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Optimistic UI: add to list immediately
    final optimisticMsg = _ChatMessage(
      sender: _Sender.me,
      text: text,
      time: _formatTime(DateTime.now()),
    );

    setState(() {
      _messages.add(optimisticMsg);
      _msgController.clear();
      _isTyping = false;
      _isSending = true;
    });

    _scrollToBottom();

    try {
      await MessageService.instance.saveMessage(
        toUserId: widget.otherUserId,
        text: text,
      );
    } catch (e) {
      // Roll back optimistic message on failure
      if (mounted) {
        setState(() => _messages.remove(optimisticMsg));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to send message. Please try again.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
            child: const Icon(Icons.arrow_back, size: 28, color: _textDark),
          ),
          const SizedBox(width: 16),
          _buildChatAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF10B981), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onCall,
            child: Icon(PhosphorIcons.phone(), color: _textDark, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAvatar() {
    if (widget.avatarUrl == null || widget.avatarUrl!.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF3F4F6),
        ),
        child: const Icon(Icons.person, color: _textLight, size: 24),
      );
    }
    return ClipOval(
      child: buildPropertyImage(
        widget.avatarUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorPlaceholder: Container(
          width: 48,
          height: 48,
          color: const Color(0xFFF3F4F6),
          child: const Icon(Icons.person, color: _textLight, size: 24),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    if (_isLoadingMessages) {
      return const Center(
        child: CircularProgressIndicator(color: _landlordPrimary),
      );
    }

    if (_loadError != null) {
      return Center(
        child: GestureDetector(
          onTap: _loadMessages,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh, color: _textLight, size: 40),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: _textLight),
              ),
            ],
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Say hello 👋',
          style: GoogleFonts.poppins(fontSize: 16, color: _textLight),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: msg.sender == _Sender.me
              ? _MyBubble(message: msg)
              : _TheirBubble(message: msg),
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                hintText: 'Type a message..',
                border: InputBorder.none,
                hintStyle: GoogleFonts.poppins(color: _textLight),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const Icon(Icons.sentiment_satisfied_alt_rounded,
              color: _textLight, size: 28),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isTyping ? _landlordPrimary : _textLight,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubbles ─────────────────────────────────────────────────────────────────

class _TheirBubble extends StatelessWidget {
  final _ChatMessage message;
  const _TheirBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Container(
            width: 44,
            height: 44,
            color: const Color(0xFFF3F4F6),
            child: const Icon(Icons.person, color: _textLight),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              message.text,
              style: GoogleFonts.poppins(fontSize: 14, color: _textDark),
            ),
          ),
        ),
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
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _landlordPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}