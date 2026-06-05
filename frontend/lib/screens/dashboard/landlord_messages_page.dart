import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

const Color _landlordPrimary = Color(0xFF059669); // Landlord Green Theme
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
  String? _selectedChatName;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _contacts = [];

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
      // TODO: Implement API call to fetch conversations
      // For now, show empty state
      setState(() {
        _conversations = [];
        _contacts = [];
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

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations
        .where((conv) =>
            conv['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showNewChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Start a new chat',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child:
                          const Icon(Icons.close, size: 28, color: _textLight),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose a contact to begin messaging.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textLight,
                  ),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipOval(
                          child: buildPropertyImage(
                            contact['avatar'],
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorPlaceholder: Container(
                              width: 52,
                              height: 52,
                              color: const Color(0xFFF3F4F6),
                              child:
                                  const Icon(Icons.person, color: _textLight),
                            ),
                          ),
                        ),
                        title: Text(
                          contact['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        subtitle: Text(
                          contact['subtitle'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _textLight,
                          ),
                        ),
                        trailing: contact['isOnline'] == true
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          final alreadyExists = _conversations
                              .any((conv) => conv['name'] == contact['name']);
                          if (!alreadyExists) {
                            _conversations.insert(0, {
                              'name': contact['name'],
                              'avatar': contact['avatar'],
                              'lastMessage': 'New conversation started',
                              'time': 'Now',
                              'unread': 0,
                              'isOnline': contact['isOnline'] ?? false,
                            });
                          }
                          widget.onChatOpen();
                          setState(() => _selectedChatName = contact['name']);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversationsList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _landlordPrimary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              child: Text('Retry'),
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
            Icon(Icons.mail_outline, size: 48, color: _textLight),
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conv = _filteredConversations[index];
        return _ConversationTile(
          name: conv['name'],
          avatar: conv['avatar'],
          lastMessage: conv['lastMessage'],
          time: conv['time'],
          unread: conv['unread'],
          isOnline: conv['isOnline'],
          onTap: () {
            widget.onChatOpen();
            setState(() => _selectedChatName = conv['name']);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedChatName != null) {
      final chat =
          _conversations.firstWhere((c) => c['name'] == _selectedChatName);
      return LandlordChatView(
        onBack: () {
          widget.onChatClose();
          setState(() => _selectedChatName = null);
        },
        name: chat['name']!,
        avatar: chat['avatar']!,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          onPressed: () => _showNewChatSheet(context),
          backgroundColor: _landlordPrimary,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient matching the PDF look
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    const Color(0xFFE8F6EF).withOpacity(0.3),
                    const Color(0xFFE8F6EF).withOpacity(0.6),
                  ],
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

              // Search Bar - Frosted Glass Effect
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

              Expanded(
                child: _buildConversationsList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unread;
  final bool isOnline;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.name,
    required this.avatar,
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
                  const SizedBox(
                      height: 22), // Placeholder to keep layout stable
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    Widget avatarWidget;

    if (avatar == 'logo_home') {
      avatarWidget = Container(
        color: const Color(0xFFE8F6EF),
        child:
            const Icon(Icons.home_rounded, color: _landlordPrimary, size: 32),
      );
    } else if (avatar == 'logo_support') {
      avatarWidget = Container(
        color: const Color(0xFFEEF2FF),
        child:
            const Icon(Icons.home_filled, color: Color(0xFF3F37C9), size: 32),
      );
    } else {
      avatarWidget = buildPropertyImage(
        avatar,
        fit: BoxFit.cover,
      );
    }

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

// ─── Data model & Chat View remain consistent with your logic ───────────────
// (Keeping the Sender enum and ChatMessage class as they are)

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

class LandlordChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onCall;
  final String name;
  final String avatar;

  const LandlordChatView({
    super.key,
    required this.onBack,
    required this.name,
    required this.avatar,
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

  late final List<_ChatMessage> _messages = [
    const _ChatMessage(
        sender: _Sender.them,
        text: 'Hi, is the room still available?',
        time: '10:45 AM'),
    const _ChatMessage(
        sender: _Sender.me,
        text:
            'Yes, it is available. When would you\nlike to come for a viewing?',
        time: '10:49 AM'),
    const _ChatMessage(
        sender: _Sender.them,
        text: 'Tomorrow at 11 AM works for\nme.',
        time: '10:50 AM'),
    const _ChatMessage(
        sender: _Sender.me, text: 'Great! See you tomorrow.', time: '10:52 AM'),
  ];

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
      setState(() {
        _isTyping = _msgController.text.trim().isNotEmpty;
      });
    });

    _pageController.forward().then((_) => _listController.forward());
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

    setState(() {
      _messages.add(_ChatMessage(
        sender: _Sender.me,
        text: text,
        time: _getFormattedTime(),
      ));
      _msgController.clear();
      _isTyping = false;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
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
                            color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Online',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _textLight)),
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
    if (widget.avatar == 'logo_home' || widget.avatar == 'logo_support') {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.avatar == 'logo_home'
                ? const Color(0xFFE8F6EF)
                : const Color(0xFFEEF2FF)),
        child: Icon(Icons.home,
            color: widget.avatar == 'logo_home'
                ? _landlordPrimary
                : const Color(0xFF3F37C9),
            size: 24),
      );
    }
    return ClipOval(
        child: buildPropertyImage(widget.avatar,
            width: 48, height: 48, fit: BoxFit.cover));
  }

  Widget _buildChatArea() {
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
              : _TheirBubble(message: msg, avatar: widget.avatar),
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
          bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              decoration: InputDecoration(
                  hintText: 'Type a message..',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.poppins(color: _textLight)),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const Icon(Icons.sentiment_satisfied_alt_rounded,
              color: _textLight, size: 28),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: _landlordPrimary, shape: BoxShape.circle),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TheirBubble extends StatelessWidget {
  final _ChatMessage message;
  final String avatar;
  const _TheirBubble({required this.message, required this.avatar});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipOval(
          child: Container(
              width: 44,
              height: 44,
              color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.person, color: _textLight))),
      const SizedBox(width: 12),
      Flexible(
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Text(message.text,
                  style: GoogleFonts.poppins(fontSize: 14, color: _textDark)))),
    ]);
  }
}

class _MyBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MyBubble({required this.message});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Flexible(
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _landlordPrimary,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(message.text,
                  style:
                      GoogleFonts.poppins(fontSize: 14, color: Colors.white)))),
    ]);
  }
}
