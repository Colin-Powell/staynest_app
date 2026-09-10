import 'package:flutter/material.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';

import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

class ProfileView extends StatefulWidget {
  final VoidCallback? onViewBookings;
  final VoidCallback? onSwitchRole;
  final void Function(String name)? onSetting;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;
  final VoidCallback? onRefer;
  final VoidCallback? onListProperty;
  final VoidCallback? onVerificationCenter;
  final VoidCallback? onBack;

  const ProfileView({
    super.key,
    this.onViewBookings,
    this.onSwitchRole,
    this.onSetting,
    this.onLogout,
    this.onEditProfile,
    this.onRefer,
    this.onListProperty,
    this.onVerificationCenter,
    this.onBack,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with TickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  late final AnimationController _staggerCtrl;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageFade;

  late String _displayName;
  late String _displaySubtitle;
  late String _avatarPath;
  late String _displayPhone;
  late String _displayRole;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('profileSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/profile_onboarding.png',
          title: 'Make StayNest yours',
          subtitle: 'Manage your account, trips, and preferences.',
          ctaText: 'Set up profile',
        ).then((_) => OnboardingPrefs.markAsSeen('profileSeen'));
      }
    });

    _displayName = AppSession.displayName;
    _displayRole = AppSession.displayRole;
    _displaySubtitle = AppSession.currentUserVerified
        ? 'Verified account'
        : AppSession.displayEmail;
    _avatarPath = AppSession.displayAvatar;
    _displayPhone = AppSession.displayPhone;

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
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    if (AppSession.apiToken == null) {
      return;
    }

    try {
      final repository = RemoteDatabaseRepository();
      final user = await repository.loadCurrentUser();

      AppSession.updateCurrentUser(user);
      await AppSession.persistSession();
      if (!mounted) return;

      setState(() {
        _displayName = AppSession.displayName;
        _displayRole = AppSession.displayRole;
        _displaySubtitle = AppSession.currentUserVerified
            ? 'Verified account'
            : AppSession.displayEmail;
        _avatarPath = AppSession.displayAvatar;
        _displayPhone = AppSession.displayPhone;
      });
    } catch (_) {
      // Keep existing cached session data if refresh fails.
    }
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
                // Header
                _buildStaggered(
                  index: 0,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Row(
                      children: [
                        Text(
                          'Profile',
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
                      bottom: MediaQuery.of(context).padding.bottom + 120,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar and Info
                        _buildStaggered(
                          index: 1,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: widget.onEditProfile,
                                  child: Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFE5E7EB),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: AppSession.buildAvatar(_avatarPath,
                                        width: 72, height: 72),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _displayRole,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _displaySubtitle,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                      if (_displayPhone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          _displayPhone,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Menu Items
                        _buildStaggered(
                          index: 2,
                          child: _MenuItem(
                            icon: Icons.person,
                            label: 'Personal Information',
                            onTap: () =>
                                widget.onSetting?.call('Personal Information'),
                          ),
                        ),
                        _buildStaggered(
                          index: 3,
                          child: _MenuItem(
                            icon: Icons.event_available_rounded,
                            label: 'My Bookings',
                            onTap: widget.onViewBookings,
                          ),
                        ),
                        _buildStaggered(
                          index: 4,
                          child: _MenuItem(
                            icon: Icons.credit_card,
                            label: 'Payment Methods',
                            onTap: () =>
                                widget.onSetting?.call('Payment Methods'),
                          ),
                        ),
                        _buildStaggered(
                          index: 5,
                          child: _MenuItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Wallet',
                            onTap: () => widget.onSetting?.call('Wallet'),
                          ),
                        ),
                        _buildStaggered(
                          index: 7,
                          child: _MenuItem(
                            icon: Icons.share,
                            label: 'Refer a Friend',
                            onTap: widget.onRefer,
                          ),
                        ),
                        _buildStaggered(
                          index: 8,
                          child: _MenuItem(
                            icon: Icons.settings,
                            label: 'Settings',
                            onTap: () => widget.onSetting?.call('Settings'),
                          ),
                        ),
                        _buildStaggered(
                          index: 9,
                          child: _MenuItem(
                            icon: Icons.info,
                            label: 'Help & Support',
                            onTap: () =>
                                widget.onSetting?.call('Help & Support'),
                          ),
                        ),

                        if (AppSession.isLandlord)
                          _buildStaggered(
                            index: 10,
                            child: _MenuItem(
                              icon: Icons.add_business_rounded,
                              label: 'List a Property',
                              onTap: widget.onListProperty ??
                                  () {
                                    Navigator.pushNamed(
                                        context, '/list_property');
                                  },
                            ),
                          ),
                        if (AppSession.isLandlord)
                          _buildStaggered(
                            index: 11,
                            child: _MenuItem(
                              icon: Icons.verified,
                              label: 'Verification Center',
                              onTap: widget.onVerificationCenter ??
                                  () {
                                    Navigator.pushNamed(
                                        context, '/verification_center');
                                  },
                            ),
                          ),

                        const SizedBox(height: 32),

                        // Logout Button
                        _buildStaggered(
                          index: 12,
                          child: _MenuItem(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            isLogout: true,
                            onTap: widget.onLogout ??
                                () => Navigator.popUntil(
                                    context, (route) => route.isFirst),
                          ),
                        ),
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

// ─── Menu Item Component ──────────────────────────────────────────────────────

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
