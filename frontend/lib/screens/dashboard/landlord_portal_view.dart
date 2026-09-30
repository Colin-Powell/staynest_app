import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/repository/remote_database_repository.dart';

import 'landlord_bookings_page.dart';
import 'landlord_messages_page.dart';
import 'landlord_overview_page.dart';
import 'landlord_properties_page.dart';
import 'landlord_settings_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

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
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  void _handleChatOpen() {
    setState(() => _isChatOpen = true);
  }

  void _handleChatClose() {
    setState(() => _isChatOpen = false);
  }

  void _openMessagesModal() {
    final size = MediaQuery.sizeOf(context);
    final inset = size.width < 768 ? 8.0 : 24.0;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.all(inset),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: (size.width - inset * 2).clamp(0.0, 880.0).toDouble(),
          height: (size.height - inset * 2).clamp(0.0, 860.0).toDouble(),
          child: Stack(
            children: [
              Positioned.fill(
                child: LandlordMessagesPage(
                  onChatOpen: _handleChatOpen,
                  onChatClose: _handleChatClose,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close messages',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded, color: _green),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(_handleChatClose);
  }

  Future<void> _loadVerificationStatus() async {
    try {
      final status = await VerificationApi.getVerificationStatus();
      final isCurrentlyApproved =
          status?['status']?.toString().toLowerCase() == 'approved';

      if (mounted) {
        // Show modal only once ever using persistent onboarding prefs
        if (isCurrentlyApproved &&
            !OnboardingPrefs.hasSeen('landlordVerifiedCongrats')) {
          await _refreshUserData();
          _showVerificationSuccessModal();
          OnboardingPrefs.markAsSeen('landlordVerifiedCongrats');
        }

        setState(() {
          _verificationStatus = status;
          _isLoadingStatus = false;
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

  // ─── Modal Redesign ──────────────────────────────────────────────────────────

  void _showVerificationSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Replaced generic icon with the requested asset
            Image.asset(
              'assets/images/congrats.webp',
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text(
              'Congratulations!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Your landlord account has been fully verified and approved.',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.poppins(fontSize: 14, color: _grey, height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                  color: _bg, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSuccessFeature(
                      PhosphorIconsFill.buildings,
                      'Add Properties',
                      'List properties and manage your portfolio'),
                  const SizedBox(height: 16),
                  _buildSuccessFeature(
                      PhosphorIconsFill.usersThree,
                      'Manage Tenants',
                      'Screen and communicate with prospects'),
                  const SizedBox(height: 16),
                  _buildSuccessFeature(
                      PhosphorIconsFill.eye,
                      'Higher Visibility',
                      'Get featured in premium search results'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(_);
                  setState(() => _selectedNav = 'Dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                ),
                child: Text('Get Started',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessFeature(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600, color: _dark)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── State Getters ───────────────────────────────────────────────────────────

  bool get _isLandlordRole => AppSession.isLandlord;

  // ─── Page Routing ────────────────────────────────────────────────────────────

  Widget _getLegacyPage() {
    switch (_selectedNav) {
      case 'Bookings':
        return const LandlordBookingsPage();
      case 'Settings':
        return const LandlordSettingsPage();
      default:
        return LandlordOverviewPage(
          onViewAllProperties: () =>
              setState(() => _selectedNav = 'Properties'),
        );
    }
  }

  Widget _buildBodyContent() {
    if (_isLoadingStatus) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 120),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24))),
            ),
          );
        },
      );
    }

    if (!_isLandlordRole) return _buildUnauthorizedView();

    final isKycApproved = _verificationStatus != null &&
        _verificationStatus!['status']?.toString().toLowerCase() == 'approved';
    if (!isKycApproved) return _buildPendingVerificationDashboard();

    if (_selectedNav == 'Properties') {
      return LandlordPropertiesPage(onAddProperty: widget.onAddProperty);
    }

    return _getLegacyPage();
  }

  // ─── Pending & Unauthorized Views ────────────────────────────────────────────

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsFill.warningCircle,
                size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 20),
            Text('Access Restricted',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 12),
            Text(
                'This portal is only available to verified landlords and agents.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: _grey, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingVerificationDashboard() {
    final statusLabel =
        _verificationStatus?['status']?.toString().toLowerCase();
    final isRejected = statusLabel == 'rejected';
    final title = isRejected
        ? 'Verification needs attention'
        : 'Verification in progress';
    final message = isRejected
        ? 'Please resubmit your identity documents to restore access to dashboard actions and listing tools.'
        : 'Your landlord KYC has been submitted. Dashboard actions and listing tools will unlock once admin approval is complete.';

    return ListView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 120),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _grey.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isRejected
                        ? PhosphorIconsFill.warningCircle
                        : PhosphorIconsFill.shieldCheck,
                    size: 32,
                    color: isRejected ? const Color(0xFFEF4444) : _green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                            letterSpacing: -0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(message,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: _grey, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/verification_center'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(isRejected ? 'Resubmit KYC' : 'View Verification',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
                child: _buildMiniStatCard('Properties', '0',
                    icon: PhosphorIconsRegular.buildings)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildMiniStatCard('Inquiries', '0',
                    icon: PhosphorIconsRegular.users)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildMiniStatCard('Bookings', '0',
                    icon: PhosphorIconsRegular.calendarCheck)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildMiniStatCard('Messages', '0',
                    icon: PhosphorIconsRegular.chatTeardropText)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value,
      {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: _green),
          const SizedBox(height: 16),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  height: 1.1)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ─── Main Scaffold ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // Clean solid background
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: refreshAll,
              color: _green,
              backgroundColor: _surface,
              child: _buildBodyContent(),
            ),
          ),
          if (!_isChatOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildSolidBottomNav(),
            ),
        ],
      ),
    );
  }

  // ─── Navigation Bar ─────────────────────────────────────────────────────────

  Widget _buildSolidBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(40), // Perfect pill shape
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(PhosphorIconsRegular.house, 'Dashboard'),
            _buildNavItem(PhosphorIconsRegular.buildings, 'Properties'),
            _buildNavItem(PhosphorIconsRegular.calendarCheck, 'Bookings'),
            _buildNavItem(PhosphorIconsRegular.chatTeardrop, 'Messages'),
            _buildNavItem(PhosphorIconsRegular.user, 'Settings',
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
      onTap: () {
        if (routeLabel == 'Messages') {
          _openMessagesModal();
          return;
        }
        setState(() => _selectedNav = routeLabel);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? _green.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? _green : _grey,
            ),
            // Fluid text expansion
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: isActive ? null : 0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    labelToShow,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
