import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/skeleton_property_card.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/repository/remote_database_repository.dart';

import 'landlord_bookings_page.dart';
import 'landlord_messages_page.dart';
import 'landlord_overview_page.dart';
import 'landlord_properties_page.dart';
import 'landlord_settings_page.dart';

class LandlordPortalView extends StatefulWidget {
  final VoidCallback onAddProperty;

  const LandlordPortalView({super.key, required this.onAddProperty});

  @override
  State<LandlordPortalView> createState() => _LandlordPortalViewState();
}

class _LandlordPortalViewState extends State<LandlordPortalView> {
  String _selectedNav = 'Dashboard';
  bool _isChatOpen = false;
  Map<String, dynamic>? _verificationStatus;
  bool _isLoadingStatus = true;
  bool _wasVerifiedBefore = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  void _handleChatOpen() {
    setState(() {
      _isChatOpen = true;
    });
  }

  void _handleChatClose() {
    setState(() {
      _isChatOpen = false;
    });
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await VerificationApi.getVerificationStatus();
      final isCurrentlyApproved =
          status?['status']?.toString().toLowerCase() == 'approved';

      if (mounted) {
        if (isCurrentlyApproved && !_wasVerifiedBefore) {
          _wasVerifiedBefore = true;
          await _refreshUserData();
          _showVerificationSuccessModal();
        }

        setState(() {
          _verificationStatus = status;
          _isLoadingStatus = false;
          if (isCurrentlyApproved) {
            _wasVerifiedBefore = true;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verificationStatus = null;
          _isLoadingStatus = false;
        });
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final repo = RemoteDatabaseRepository();
      final userData = await repo.loadCurrentUser();
      AppSession.updateCurrentUser(userData);
        } catch (_) {
      // Silently fail, user data is already loaded
    }
  }

  Future<void> refreshAll() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await _refreshUserData();
      await _loadVerificationStatus();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showVerificationSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD1FAE5),
                ),
                child: Icon(
                  PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  size: 48,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account is now verified',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSuccessFeature(
                      PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                      'Manage Tenants',
                      'Screen and communicate with potential tenants',
                    ),
                    const SizedBox(height: 12),
                    _buildSuccessFeature(
                      PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                      'Add Properties',
                      'List your properties and manage listings',
                    ),
                    const SizedBox(height: 12),
                    _buildSuccessFeature(
                      PhosphorIcons.eye(PhosphorIconsStyle.fill),
                      'Higher Visibility',
                      'Verified landlords get featured in more searches',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      (MediaQuery.of(_).size.width - 64).clamp(0.0, 360.0),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(_);
                      setState(() => _selectedNav = 'Dashboard');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessFeature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF059669)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _isLandlordRole => AppSession.isLandlord;

  bool get _isVerificationApproved =>
      _verificationStatus?['status']?.toString().toLowerCase() == 'approved';

  bool get _hasVerificationSubmitted =>
      _verificationStatus != null &&
      _verificationStatus!['status']?.toString().toLowerCase() == 'submitted';

  bool get _isVerificationRejected =>
      _verificationStatus != null &&
      _verificationStatus!['status']?.toString().toLowerCase() == 'rejected';

  Widget _getLegacyPage() {
    switch (_selectedNav) {
case 'Bookings':
        return const LandlordBookingsPage();
      case 'Messages':
        return LandlordMessagesPage(
          onChatOpen: _handleChatOpen,
          onChatClose: _handleChatClose,
        );
      case 'Settings':
        return const LandlordSettingsPage();
      default:
        return const LandlordOverviewPage();
    }
  }

  Widget _buildBodyContent() {
    if (_isLoadingStatus) {
      return ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: SkeletonPropertyCard(width: double.infinity, margin: EdgeInsets.zero),
          );
        },
      );
    }

    if (!_isLandlordRole) {
      return _buildUnauthorizedView();
    }

    if (!AppSession.currentUserVerified) {
      if (_isVerificationRejected) {
        return _buildVerificationRequiredView();
      }
      if (_verificationStatus == null || !_isVerificationApproved) {
        return _buildVerificationRequiredView();
      }
    }

    if (_selectedNav == 'Properties') {
      return LandlordPropertiesPage(onAddProperty: widget.onAddProperty);
    }

    return _getLegacyPage();
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.warning(PhosphorIconsStyle.fill),
                size: 72, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              'Access restricted',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This portal is only available to verified landlords and agents.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationRequiredView() {
    final message = _isVerificationRejected
        ? 'Your verification was rejected. Please resubmit your documents.'
        : 'You need to complete landlord verification before accessing the portal.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                size: 72, color: const Color(0xFF059669)),
            const SizedBox(height: 20),
            Text(
              _isVerificationRejected
                  ? 'Verification required'
                  : 'Verify your account',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/verification_center'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                _isVerificationRejected
                    ? 'Resubmit Verification'
                    : 'Start Verification',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictedPortalView() {
    final statusLabel = _hasVerificationSubmitted
        ? 'Pending approval'
        : 'Verification required';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.lockKey(PhosphorIconsStyle.fill),
                size: 72, color: const Color(0xFF0F766E)),
            const SizedBox(height: 20),
            Text(
              statusLabel,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your landlord verification has been submitted and is under review. The portal is available, but pages will remain locked until approval.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRefreshing ? null : refreshAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isRefreshing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : Text(
                            'Refresh Status',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/verification_center'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'View Details',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 1. Global Background
          Container(
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

          // 2. Active Page Content with Pull-to-Refresh
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: refreshAll,
              color: const Color(0xFF059669),
              child: _buildBodyContent(),
            ),
          ),

          // 3. Clean Floating Glass Bottom Navigation
          if (!_isChatOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildGlassBottomNav(),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      child: _GlassContainer(
        blur: 25,
        opacity: 0.85,
        borderRadius: BorderRadius.circular(32),
        borderWidth: 1.5,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(
                PhosphorIcons.house(PhosphorIconsStyle.fill), 'Dashboard'),
            _buildNavItem(
                PhosphorIcons.buildings(PhosphorIconsStyle.fill), 'Properties'),
            _buildNavItem(
                PhosphorIcons.calendarCheck(PhosphorIconsStyle.fill), 'Bookings'),
            _buildNavItem(
                PhosphorIcons.chatTeardrop(PhosphorIconsStyle.fill), 'Messages'),
            _buildNavItem(
                PhosphorIcons.userCircle(PhosphorIconsStyle.fill), 'Settings',
                displayLabel: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String routeLabel,
      {String? displayLabel}) {
    final bool isActive = _selectedNav == routeLabel;
    final String labelToShow = displayLabel ?? routeLabel;

    return GestureDetector(
      onTap: () => setState(() => _selectedNav = routeLabel),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF059669).withValues(alpha: 0.12) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isActive ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
            ),
            // Only reveal the text when the tab is active
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                labelToShow,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF059669),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ─── Glassmorphism Core Utility (Local to Portal) ────────────────────────
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderWidth;

  const _GlassContainer({
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 15.0,
    this.opacity = 0.55,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}