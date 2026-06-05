// lib/screens/dashboard/landlord_chat_view.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

const Color _landlordPrimary = Color(0xFF059669); // Landlord Green Theme

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

class _LandlordChatViewState extends State<LandlordChatView> with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _pageController;
  late final AnimationController _listController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  bool _isTyping = false;

  final List<_ChatMessage> _messages = const [
    _ChatMessage(
        sender: _Sender.them,
        text: 'Hi, is the room still available?',
        time: '10:45 AM'),
    _ChatMessage(
        sender: _Sender.me,
        text: 'Yes, it is available. When would you\nlike to come for a viewing?',
        time: '10:49 AM'),
    _ChatMessage(
        sender: _Sender.them,
        text: 'Tomorrow at 11 AM works for\nme.',
        time: '10:50 AM'),
    _ChatMessage(
        sender: _Sender.me, text: 'Great! See you tomorrow.', time: '10:52 AM'),
  ];

  @override
  void initState() {
    super.initState();
    // Page Entrance Animation
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));
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
    // Hook into your message-sending logic here
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
              errorPlaceholder: Container(
                width: 48, height: 48, color: const Color(0xFFF3F4F6),
                child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
              ),
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
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Green dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Call button (PhosphorIcons used as a function to prevent error)
          GestureDetector(
            onTap: widget.onCall,
            child: Icon(PhosphorIcons.phone(), color: Colors.black, size: 28),
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
            style: GoogleFonts.poppins(
              fontSize: 13,
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
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message..',
                hintStyle: GoogleFonts.poppins(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: _landlordPrimary,
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
            errorPlaceholder: Container(
              width: 44, height: 44, color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.person, color: Color(0xFF9CA3AF)),
            ),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.time,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9CA3AF),
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
                  offset: const Offset(0, 6),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    message.time,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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