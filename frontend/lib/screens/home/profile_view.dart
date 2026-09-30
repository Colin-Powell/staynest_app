import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';

import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

// --- Airbnb Style Constants ---
const Color _textDark = Color(0xFF222222);
const Color _textLight = Color(0xFF717171);
const Color _airbnbPink = Color(0xFFE61E4D);
const Color _dividerColor = Color(0xFFEBEBEB);
const double _maxWebWidth = 1120.0; // Standard Airbnb desktop width

class ProfileView extends StatefulWidget {
  final VoidCallback? onViewBookings;
  final VoidCallback? onSwitchRole;
  final void Function(String name)? onSetting;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;
  final VoidCallback? onMyProfile;
  final VoidCallback? onRefer;
  final VoidCallback? onListProperty;
  final VoidCallback? onVerificationCenter;
  final VoidCallback? onBack;
  final String? desktopSelectedRoute;
  final Widget? desktopHelperContent;
  final VoidCallback? onCloseDesktopHelper;

  const ProfileView({
    super.key,
    this.onViewBookings,
    this.onSwitchRole,
    this.onSetting,
    this.onLogout,
    this.onEditProfile,
    this.onMyProfile,
    this.onRefer,
    this.onListProperty,
    this.onVerificationCenter,
    this.onBack,
    this.desktopSelectedRoute,
    this.desktopHelperContent,
    this.onCloseDesktopHelper,
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

  int _selectedDesktopMenuIndex = 0;

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

    _loadSessionData();

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

  void _loadSessionData() {
    _displayName = AppSession.displayName;
    _displayRole = AppSession.displayRole;
    _displaySubtitle = AppSession.currentUserVerified
        ? 'Verified account'
        : AppSession.displayEmail;
    _avatarPath = AppSession.displayAvatar;
    _displayPhone = AppSession.displayPhone;
  }

  Future<void> _refreshProfile() async {
    if (AppSession.apiToken == null) return;
    try {
      final repository = RemoteDatabaseRepository();
      final user = await repository.loadCurrentUser();

      AppSession.updateCurrentUser(user);
      await AppSession.persistSession();
      if (!mounted) return;

      setState(() => _loadSessionData());
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          if (isDesktop) {
            return SlideTransition(
              position: _pageSlide,
              child: FadeTransition(
                opacity: _pageFade,
                child: _buildDesktopLayout(),
              ),
            );
          }

          return SlideTransition(
            position: _pageSlide,
            child: FadeTransition(
              opacity: _pageFade,
              child: _buildMobileLayout(),
            ),
          );
        },
      ),
    );
  }

  // ─── DESKTOP LAYOUT (Matches Screenshot Mockup) ──────────────────────────

  Widget _buildDesktopLayout() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWebWidth),
          child: Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Sidebar Navigation
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 24, bottom: 32),
                          child: Text(
                            'Profile',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.person_outline,
                          label: 'About me',
                          isSelected: widget.desktopHelperContent == null &&
                              _selectedDesktopMenuIndex == 0,
                          onTap: () {
                            if (widget.desktopHelperContent != null) {
                              widget.onCloseDesktopHelper?.call();
                            }
                            setState(() => _selectedDesktopMenuIndex = 0);
                          },
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.people_outline,
                          label: 'Connections',
                          isSelected: _selectedDesktopMenuIndex == 1,
                          onTap: () =>
                              setState(() => _selectedDesktopMenuIndex = 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Divider(color: _dividerColor),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.event_available_rounded,
                          label: 'My Bookings',
                          isSelected: widget.desktopSelectedRoute ==
                                  '/tenant_bookings' ||
                              widget.desktopSelectedRoute ==
                                  '/landlord_bookings',
                          onTap: widget.onViewBookings ?? () {},
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.person_outline_rounded,
                          label: 'Personal Information',
                          isSelected:
                              widget.desktopSelectedRoute == '/edit_profile',
                          onTap: widget.onEditProfile ?? () {},
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.credit_card_rounded,
                          label: 'Payment Methods',
                          isSelected:
                              widget.desktopSelectedRoute == '/payment_methods',
                          onTap: () =>
                              widget.onSetting?.call('Payment Methods'),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet',
                          isSelected: widget.desktopSelectedRoute == '/wallet',
                          onTap: () => widget.onSetting?.call('Wallet'),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.card_giftcard_rounded,
                          label: 'Refer a Friend',
                          isSelected:
                              widget.desktopSelectedRoute == '/referral',
                          onTap: widget.onRefer ?? () {},
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.reviews_outlined,
                          label: 'Reviews',
                          isSelected: widget.desktopSelectedRoute == '/reviews',
                          onTap: () => widget.onSetting?.call('Reviews'),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          isSelected:
                              widget.desktopSelectedRoute == '/settings',
                          onTap: () => widget.onSetting?.call('Settings'),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          isSelected:
                              widget.desktopSelectedRoute == '/help_support',
                          onTap: () => widget.onSetting?.call('Help & Support'),
                        ),
                        _DesktopSidebarItem(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notification Settings',
                          isSelected: widget.desktopSelectedRoute ==
                              '/notification_settings',
                          onTap: () =>
                              widget.onSetting?.call('Notification Settings'),
                        ),
                        if (AppSession.isLandlord) ...[
                          _DesktopSidebarItem(
                            icon: Icons.add_business_rounded,
                            label: 'List a Property',
                            isSelected: false,
                            onTap: widget.onListProperty ?? () {},
                          ),
                          _DesktopSidebarItem(
                            icon: Icons.verified_outlined,
                            label: 'Verification Center',
                            isSelected: widget.desktopSelectedRoute ==
                                '/verification_center',
                            onTap: widget.onVerificationCenter ?? () {},
                          ),
                        ],
                        _DesktopSidebarItem(
                          icon: Icons.logout_rounded,
                          label: 'Logout',
                          isSelected: false,
                          isLogout: true,
                          onTap: widget.onLogout ??
                              () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                        ),
                      ],
                    ),
                  ),
                ),

                // Vertical Divider
                const VerticalDivider(
                    color: _dividerColor, width: 1, thickness: 1),

                // 2. Main Content Area
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: widget.desktopHelperContent == null ? 80 : 32,
                      right: 24,
                    ),
                    child: widget.desktopHelperContent == null
                        ? _selectedDesktopMenuIndex == 0
                            ? _buildDesktopAboutMeContent()
                            : Center(
                                child: Text(
                                  'Content for this section goes here.',
                                  style: GoogleFonts.poppins(
                                      color: _textLight, fontSize: 16),
                                ),
                              )
                        : ClipRect(child: widget.desktopHelperContent!),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAboutMeContent() {
    // Determine user initial for the mockup avatar fallback
    final initial =
        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Text(
              'About me',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: _textDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onMyProfile,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _dividerColor, width: 1.5),
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        // Profile Card & Promo Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mockup Left Card
            Container(
              width: 340,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: _dividerColor, width: 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFEBE6FE), // Light purple mockup color
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _avatarPath.isNotEmpty
                        ? AppSession.buildAvatar(_avatarPath,
                            width: 104, height: 104)
                        : Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.poppins(
                                fontSize: 40,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                    0xFF3F37C9), // Deep purple letter
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _displayRole,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: _textLight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 64),

            // Mockup Right Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Complete your profile',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your StayNest profile is an important part of every reservation. Complete yours to help other hosts and guests get to know you.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: _textLight,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: widget.onMyProfile ?? () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _airbnbPink,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Get started',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 64),
        const Divider(color: _dividerColor, thickness: 1),
        const SizedBox(height: 32),

        // Reviews Link
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onSetting?.call('Reviews'),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 24, color: _textDark),
                const SizedBox(width: 16),
                Text(
                  "Show reviews I've written",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: _textDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── MOBILE LAYOUT (Original Logic Preserved) ─────────────────────────────

  Widget _buildMobileLayout() {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildStaggered(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  Text(
                    'Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
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
                            onTap: widget.onMyProfile,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displayRole,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _displaySubtitle,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ),
                                if (_displayPhone.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _displayPhone,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9CA3AF),
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
                      onTap: () => widget.onSetting?.call('Payment Methods'),
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
                      onTap: () => widget.onSetting?.call('Help & Support'),
                    ),
                  ),

                  if (AppSession.isLandlord)
                    _buildStaggered(
                      index: 10,
                      child: _MenuItem(
                        icon: Icons.add_business_rounded,
                        label: 'List a Property',
                        onTap: widget.onListProperty ??
                            () =>
                                Navigator.pushNamed(context, '/list_property'),
                      ),
                    ),
                  if (AppSession.isLandlord)
                    _buildStaggered(
                      index: 11,
                      child: _MenuItem(
                        icon: Icons.verified,
                        label: 'Verification Center',
                        onTap: widget.onVerificationCenter ??
                            () => Navigator.pushNamed(
                                context, '/verification_center'),
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
    );
  }
}

// ─── Desktop Sidebar Item Component ───────────────────────────────────────────

class _DesktopSidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isLogout;
  final VoidCallback onTap;

  const _DesktopSidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isLogout = false,
    required this.onTap,
  });

  @override
  State<_DesktopSidebarItem> createState() => _DesktopSidebarItemState();
}

class _DesktopSidebarItemState extends State<_DesktopSidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor =
        widget.isLogout ? const Color(0xFFEF4444) : _textDark;
    final Color textColor =
        widget.isLogout ? const Color(0xFFEF4444) : _textDark;

    final bool isActive = widget.isSelected || _isHovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFF7F7F7) // Active grey background
                : _isHovered
                    ? const Color(0xFFF7F7F7)
                        .withOpacity(0.5) // Hover subtle grey
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 24, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Menu Item Component ───────────────────────────────────────────────

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
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
