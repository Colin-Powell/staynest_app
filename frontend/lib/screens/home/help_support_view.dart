import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportView extends StatefulWidget {
  final VoidCallback onBack;
  const HelpSupportView({super.key, required this.onBack});

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
  // FAQ items — expandable
  static const List<Map<String, String>> _faqs = [
    {
      'q': 'How do I search for a property?',
      'a': 'Use the search bar on the home screen. You can filter by category, price, location, and number of bedrooms. Tap on any property card to see full details.',
    },
    {
      'q': 'How do I book a property?',
      'a': 'Open a property, tap the "Book Now" button, choose your check-in and check-out dates, then confirm. The landlord will review and approve your request.',
    },
    {
      'q': 'Can I cancel a booking?',
      'a': 'Yes. Go to Profile ? My Bookings, tap on an upcoming booking, and tap "Cancel". Cancellation policies vary per property — check the listing for details.',
    },
    {
      'q': 'How do I verify my account?',
      'a': 'After registration, check your email for an OTP code and enter it on the verification screen. Verified accounts get a checkmark badge and more trust from landlords.',
    },
    {
      'q': 'What payment methods are supported?',
      'a': 'StayNest currently supports M-Pesa and card payments. Go to Profile ? Payment Methods to manage your linked accounts.',
    },
    {
      'q': 'How does the referral program work?',
      'a': 'Share your unique referral code from Profile ? Refer a Friend. When a friend signs up and completes a booking, you both earn Ksh 500 credit.',
    },
    {
      'q': 'I found a suspicious listing. What do I do?',
      'a': 'Tap the flag icon on the property page to report it, or email us at support@staynest.top with the property link and a description of the issue.',
    },
  ];

  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Help & Support',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: [
                  // Quick actions
                  const SizedBox(height: 8),
                  _QuickAction(
                    icon: Icons.headset_mic_rounded,
                    label: 'Contact Support',
                    subtitle: 'support@staynest.top',
                    color: const Color(0xFF4F46E5),
                    onTap: () => _launchEmail(
                      to: 'support@staynest.top',
                      subject: 'StayNest Support Request',
                      body: 'Hi StayNest Support,\n\nI need help with:\n',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickAction(
                    icon: Icons.flag_outlined,
                    label: 'Report a Problem',
                    subtitle: 'Tell us what went wrong',
                    color: const Color(0xFFEF4444),
                    onTap: () => _launchEmail(
                      to: 'support@staynest.top',
                      subject: 'StayNest Problem Report',
                      body: 'Hi,\n\nI encountered a problem:\n\nDescription:\n\nSteps to reproduce:\n',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickAction(
                    icon: Icons.lock_outline,
                    label: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    color: const Color(0xFF6B7280),
                    onTap: () => Navigator.pushNamed(context, '/privacy'),
                  ),

                  const SizedBox(height: 28),
                  const Text('Frequently Asked Questions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 12),

                  // FAQ accordion
                  ...List.generate(_faqs.length, (i) {
                    final faq = _faqs[i];
                    final isOpen = _expanded.contains(i);
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            if (isOpen) _expanded.remove(i); else _expanded.add(i);
                          }),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(faq['q']!,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827))),
                                ),
                                AnimatedRotation(
                                  turns: isOpen ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF9CA3AF)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(faq['a']!,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    height: 1.6)),
                          ),
                          crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      ],
                    );
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchEmail({required String to, required String subject, required String body}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open email. Please contact support@staynest.top'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
