import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportView extends StatefulWidget {
  final VoidCallback onBack;
  const HelpSupportView({super.key, required this.onBack});

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageFade;

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I search for a property?',
      'a':
          'Use the search bar on the home screen. You can filter by category, price, location, and number of bedrooms. Tap on any property card to see full details.',
    },
    {
      'q': 'How do I book a property?',
      'a':
          'Open a property, tap the "Book Now" button, choose your check-in and check-out dates, then confirm. The landlord will review and approve your request.',
    },
    {
      'q': 'Can I cancel a booking?',
      'a':
          'Yes. Go to Profile → My Bookings, tap on an upcoming booking, and tap "Cancel". Cancellation policies vary per property - check the listing for details.',
    },
    {
      'q': 'How do I verify my account?',
      'a':
          'After registration, check your email for an OTP code and enter it on the verification screen. Verified accounts get a checkmark badge and more trust from landlords.',
    },
    {
      'q': 'What payment methods are supported?',
      'a':
          'StayNest currently supports M-Pesa and card payments. Go to Profile → Payment Methods to manage your linked accounts.',
    },
    {
      'q': 'How does the referral program work?',
      'a':
          'Share your unique referral code from Profile → Refer a Friend. When a friend signs up and completes a booking, you both earn Ksh 500 credit.',
    },
    {
      'q': 'I found a suspicious listing. What do I do?',
      'a':
          'Tap the flag icon on the property page to report it, or email us at support@staynest.top with the property link and a description of the issue.',
    },
  ];

  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pageSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageFade = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);

    _pageCtrl.forward().then((_) => _staggerCtrl.forward());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Widget _buildStaggered({required int index, required Widget child}) {
    final double start = (index * 0.08).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _pageSlide,
      child: FadeTransition(
        opacity: _pageFade,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header identically matching ProfileView
                _buildStaggered(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.chevron_left_rounded,
                              size: 32, color: Colors.black),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 32,
                    ),
                    children: [
                      // Subtitle Header
                      _buildStaggered(
                        index: 1,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 24, right: 24, bottom: 8),
                          child: Text(
                            'How can we help you today?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),

                      // Quick Action Buttons (now seamlessly matching _MenuItem)
                      _buildStaggered(
                        index: 2,
                        child: _QuickAction(
                          icon: Icons.headset_mic_rounded,
                          label: 'Contact Support',
                          subtitle: 'support@staynest.top',
                          onTap: () => _launchEmail(
                              to: 'support@staynest.top',
                              subject: 'StayNest Support Request',
                              body:
                                  'Hi StayNest Support,\n\nI need help with:\n'),
                        ),
                      ),
                      _buildStaggered(
                        index: 3,
                        child: _QuickAction(
                          icon: Icons.outlined_flag_rounded,
                          label: 'Report a Problem',
                          subtitle: 'Tell us what went wrong',
                          onTap: () => _launchEmail(
                              to: 'support@staynest.top',
                              subject: 'StayNest Problem Report',
                              body:
                                  'Hi,\n\nI encountered a problem:\n\nDescription:\n\nSteps to reproduce:\n'),
                        ),
                      ),
                      _buildStaggered(
                        index: 4,
                        child: _QuickAction(
                          icon: Icons.lock_outline_rounded,
                          label: 'Privacy Policy',
                          subtitle: 'How we handle your data',
                          onTap: () => Navigator.pushNamed(context, '/privacy'),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // FAQ Section Title
                      _buildStaggered(
                        index: 5,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'FREQUENTLY ASKED QUESTIONS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FAQ Items
                      _buildStaggered(
                        index: 6,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: List.generate(_faqs.length, (i) {
                              final faq = _faqs[i];
                              final isOpen = _expanded.contains(i);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFFF9FAFB)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isOpen
                                        ? const Color(0xFFE5E7EB)
                                        : const Color(0xFFF3F4F6),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() {
                                        if (isOpen) {
                                          _expanded.remove(i);
                                        } else {
                                          _expanded.add(i);
                                        }
                                      }),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                faq['q']!,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            AnimatedRotation(
                                              turns: isOpen ? 0.5 : 0,
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              child: const Icon(
                                                Icons.keyboard_arrow_down_rounded,
                                                color: Color(0xFF9CA3AF),
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 16),
                                        child: Text(
                                          faq['a']!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF4B5563),
                                            height: 1.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      crossFadeState: isOpen
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration:
                                          const Duration(milliseconds: 200),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(
      {required String to,
      required String subject,
      required String body}) async {
    final uri = Uri(
        scheme: 'mailto',
        path: to,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not open email. Please contact support@staynest.top'),
          behavior: SnackBarBehavior.floating));
    }
  }
}

// ─── Quick Action Item (Perfectly matching ProfileView's _MenuItem) ───────────

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    reverseDuration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 0.96).animate(
    CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOutCubic),
  );

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverCtrl.forward(),
      onTapUp: (_) {
        _hoverCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(widget.icon, size: 28, color: const Color(0xFF6B7280)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: Color(0xFFD1D5DB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}