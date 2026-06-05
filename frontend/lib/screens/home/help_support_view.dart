import 'package:flutter/material.dart';
import 'package:property_app/app_theme.dart';

class HelpSupportView extends StatefulWidget {
  final VoidCallback onBack;

  const HelpSupportView({super.key, required this.onBack});

  @override
  State<HelpSupportView> createState() => _HelpSupportViewState();
}

class _HelpSupportViewState extends State<HelpSupportView> {
  static const List<Map<String, dynamic>> _menuItems = [
    {
      'label': 'FAQs',
      'icon': Icons.help_outline_rounded,
      'details':
          'Frequently asked questions about searching, bookings, and account management.',
    },
    {
      'label': 'Contact Support',
      'icon': Icons.headset_mic_rounded,
      'details':
          'Reach the support team for booking help, property issues, and account questions.',
    },
    {
      'label': 'Safety Tools',
      'icon': Icons.shield_outlined,
      'details':
          'Learn how to stay safe while browsing properties and interacting with landlords.',
    },
    {
      'label': 'Report a Problem',
      'icon': Icons.flag_outlined,
      'details':
          'Submit a report if you encounter booking issues, listing errors, or app problems.',
    },
    {
      'label': 'Terms & Conditions',
      'icon': Icons.description_outlined,
      'details':
          'View the terms that govern StayNest use, liability, and user responsibilities.',
    },
    {
      'label': 'Privacy Policy',
      'icon': Icons.lock_outline_rounded,
      'details':
          'See how StayNest uses and protects your data before connecting to real backend services.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Row(
                children: [
                  _BackButton(onTap: widget.onBack),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Help & Support',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _menuItems.length + 2, // items + divider + logout
                itemBuilder: (context, index) {
                  if (index < _menuItems.length) {
                    final item = _menuItems[index];

                    return InkWell(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/how_it_works',
                        arguments: {
                          'title': item['label'],
                          'subtitle': '${item['label']} details',
                          'details': item['details'],
                        },
                      ),
                      highlightColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['label'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (index == _menuItems.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 8, bottom: 24),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE5E7EB),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Back Button ─────────────────────────────────────────────────────────────

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          color: Colors.transparent, // Increases touch target
          child: const Icon(
            Icons.arrow_back,
            size: 28,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// ─── Version Tile ─────────────────────────────────────────────────────────────

class _VersionTile extends StatefulWidget {
  @override
  State<_VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<_VersionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF9FAFB) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _pressed ? AppTheme.borderMid : AppTheme.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_pressed ? 0.0 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Version',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              'v1.0.0',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
