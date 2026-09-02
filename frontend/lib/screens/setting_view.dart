import 'package:flutter/material.dart';

import 'package:property_app/session/app_session.dart';

class SettingView extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String title)? onItemTap;
  final VoidCallback? onLogout;

  const SettingView({
    super.key,
    required this.onBack,
    this.onItemTap,
    this.onLogout,
  });

  @override
  State<SettingView> createState() => _SettingViewState();
}

class _SettingViewState extends State<SettingView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageFade;

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
        .animate(
            CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
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
                // Header mimicking ProfileView but with a back button
                _buildStaggered(
                  index: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 24, 24),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.chevron_left_rounded,
                              size: 32, color: Colors.black),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Settings',
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
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStaggered(
                          index: 1,
                          child: _buildSectionHeader('General'),
                        ),
                        _buildStaggered(
                          index: 2,
                          child: _MenuItem(
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            onTap: () {
                              Navigator.pushNamed(
                                  context, '/notification_settings');
                            },
                          ),
                        ),
                        _buildStaggered(
                          index: 4,
                          child: _MenuItem(
                            icon: Icons.lock_outline_rounded,
                            label: 'Privacy & Security',
                            onTap: () {
                              Navigator.pushNamed(context, '/privacy');
                            },
                          ),
                        ),
                        _buildStaggered(
                          index: 7,
                          child: _MenuItem(
                            icon: Icons.info_outline_rounded,
                            label: 'About StayNest',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutView(),
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.onLogout != null) ...[
                          const SizedBox(height: 32),
                          _buildStaggered(
                            index: 8,
                            child: _MenuItem(
                              icon: Icons.logout_rounded,
                              label: 'Logout',
                              isLogout: true,
                              onTap: widget.onLogout,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Menu Item Component (Exactly matching ProfileView) ───────────────────────

class _MenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLogout;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isLogout = false,
  });

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem>
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
    final Color iconColor =
        widget.isLogout ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    final Color textColor =
        widget.isLogout ? const Color(0xFFEF4444) : const Color(0xFF111827);

    return GestureDetector(
      onTapDown: (_) => _hoverCtrl.forward(),
      onTapUp: (_) {
        _hoverCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _hoverCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(widget.icon, size: 28, color: iconColor),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),
              if (!widget.isLogout)
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

// ─── New Clean About Page (Matches Design Language) ───────────────────────────

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded,
              size: 32, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'About StayNest',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.webp',
              height: 200,
              width: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),

            // Version Info
            Text(
              'Version ${AppSession.currentAppVersion} (Build ${AppSession.currentAppBuildNumber})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 48),

            // Contact Support
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email_outlined, color: Color(0xFF6B7280)),
                  SizedBox(width: 12),
                  Text(
                    'support@staynest.top',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Copyright at the bottom
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 32,
              ),
              child: const Text(
                '© 2026 StayNest. All rights reserved.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
