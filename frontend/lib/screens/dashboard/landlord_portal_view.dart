import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:property_app/session/app_session.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/services/verification_api.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/screens/communication/notifications_view.dart';
import 'package:property_app/screens/landlord/listing_flow.dart';
import 'package:property_app/services/notification_api.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';

import 'landlord_bookings_page.dart';
import 'landlord_booking_detail_page.dart';
import 'landlord_calendar_page.dart';
import 'landlord_messages_page.dart';
import 'landlord_overview_page.dart';
import 'landlord_property_management_page.dart';
import 'landlord_properties_page.dart';
import 'landlord_settings_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordPortalView extends StatefulWidget {
  final VoidCallback? onSwitchToTenantPortal;

  const LandlordPortalView({super.key, this.onSwitchToTenantPortal});

  @override
  State<LandlordPortalView> createState() => _LandlordPortalViewState();
}

class _LandlordPortalViewState extends State<LandlordPortalView> {
  String _selectedNav = 'Dashboard';
  Map<String, dynamic>? _propertyDetail;
  Map<String, dynamic>? _bookingDetail;
  Map<String, dynamic>? _listingProperty;
  String _listingReturnNav = 'Dashboard';
  String _calendarReturnNav = 'Bookings';
  String? _calendarPropertyId;
  String? _calendarPropertyTitle;
  String _bookingDetailReturnNav = 'Bookings';
  bool _isChatOpen = false;
  Map<String, dynamic>? _verificationStatus;
  bool _isLoadingStatus = true;
  bool _isRefreshing = false;
  bool _showDesktopNotifications = false;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    _refreshUnreadNotificationCount();
  }

  void _handleChatOpen() {
    setState(() => _isChatOpen = true);
  }

  void _handleChatClose() {
    setState(() => _isChatOpen = false);
  }

  void _openPropertyManagement(Map<String, dynamic> property) {
    setState(() {
      _propertyDetail = Map<String, dynamic>.from(property);
      _selectedNav = 'Property Details';
    });
  }

  void _closePropertyManagement() {
    setState(() {
      _propertyDetail = null;
      _selectedNav = 'Properties';
    });
  }

  void _openListingFlow({
    Map<String, dynamic>? property,
    String? returnNav,
  }) {
    _listingReturnNav = returnNav ?? _selectedNav;
    setState(() {
      _listingProperty =
          property == null ? null : Map<String, dynamic>.from(property);
      _selectedNav = 'New Listing';
    });
  }

  void _closeListingFlow({bool completed = false}) {
    setState(() {
      _selectedNav = completed
          ? (_listingProperty == null ? 'Properties' : _listingReturnNav)
          : _listingReturnNav;
      _listingProperty = null;
    });
  }

  void _openCalendar({String? propertyId, String? propertyTitle}) {
    _calendarReturnNav = _selectedNav;
    setState(() {
      _calendarPropertyId = propertyId;
      _calendarPropertyTitle = propertyTitle;
      _selectedNav = 'Calendar';
    });
  }

  void _closeCalendar() {
    setState(() => _selectedNav = _calendarReturnNav);
  }

  void _openBookingDetails(Map<String, dynamic> booking,
      {String returnNav = 'Bookings'}) {
    setState(() {
      _bookingDetail = Map<String, dynamic>.from(booking);
      _bookingDetailReturnNav = returnNav;
      _selectedNav = 'Booking Details';
    });
  }

  void _closeBookingDetails(bool changed) {
    setState(() {
      _bookingDetail = null;
      _selectedNav = _bookingDetailReturnNav;
    });
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final response = await NotificationApi.fetchNotifications(limit: 1);
      final meta = response['meta'];
      final unreadCount = meta is Map
          ? int.tryParse(meta['unreadCount']?.toString() ?? '') ?? 0
          : 0;

      if (!mounted) return;
      setState(() => _unreadNotificationCount = unreadCount);
    } catch (_) {
      // Keep the count as-is when the notification API is unavailable.
    }
  }

  void _toggleDesktopNotifications() {
    final show = !_showDesktopNotifications;
    setState(() => _showDesktopNotifications = show);
    if (show) {
      _refreshUnreadNotificationCount();
    }
  }

  void _openMessagesModal() {
    showResponsiveModalSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        final height = MediaQuery.sizeOf(dialogContext).height * 0.94;

        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
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
        );
      },
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

  bool get _isLandlordRole => AppSession.hasLandlordAccess;

  // ─── Page Routing ────────────────────────────────────────────────────────────

  Widget _getLegacyPage() {
    switch (_selectedNav) {
      case 'Property Details':
        return LandlordPropertyManagementPage(
          property: _propertyDetail ?? <String, dynamic>{},
          onBack: _closePropertyManagement,
          onNavigateToBookings: () => setState(() => _selectedNav = 'Bookings'),
          onOpenCalendar: () => _openCalendar(
            propertyId: _propertyDetail?['id']?.toString(),
            propertyTitle: _propertyDetail?['title']?.toString(),
          ),
          onEditProperty: (property) => _openListingFlow(
            property: property,
            returnNav: 'Property Details',
          ),
        );
      case 'Bookings':
        return LandlordBookingsPage(
          onOpenCalendar: _openCalendar,
          onOpenBookingDetail: (booking) =>
              _openBookingDetails(booking, returnNav: 'Bookings'),
        );
      case 'Calendar':
        return LandlordCalendarPage(
          propertyId: _calendarPropertyId,
          propertyTitle: _calendarPropertyTitle,
          onBack: _closeCalendar,
          onOpenBookingDetail: (booking) =>
              _openBookingDetails(booking, returnNav: 'Calendar'),
        );
      case 'Booking Details':
        return LandlordBookingDetailPage(
          booking: _bookingDetail ?? <String, dynamic>{},
          onClose: _closeBookingDetails,
        );
      case 'New Listing':
        return AddListingFlow(
          property: _listingProperty,
          onClose: () => _closeListingFlow(),
          onComplete: () => _closeListingFlow(completed: true),
        );
      case 'Settings':
        return LandlordSettingsPage(
          onSwitchToTenantPortal: widget.onSwitchToTenantPortal,
        );
      default:
        return LandlordOverviewPage(
          onViewAllProperties: () =>
              setState(() => _selectedNav = 'Properties'),
        );
    }
  }

  Widget _buildBodyContent({bool isDesktop = false}) {
    if (_isLoadingStatus) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(24, 24, 24,
            MediaQuery.of(context).padding.bottom + (isDesktop ? 32 : 120)),
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
    if (!isKycApproved) {
      return _buildPendingVerificationDashboard(isDesktop: isDesktop);
    }

    if (_selectedNav == 'Properties') {
      return LandlordPropertiesPage(
        onAddProperty: _openListingFlow,
        onOpenProperty: _openPropertyManagement,
      );
    }

    if (_selectedNav == 'Property Details') {
      return LandlordPropertyManagementPage(
        property: _propertyDetail ?? <String, dynamic>{},
        onBack: _closePropertyManagement,
        onNavigateToBookings: () => setState(() => _selectedNav = 'Bookings'),
        onOpenCalendar: () => _openCalendar(
          propertyId: _propertyDetail?['id']?.toString(),
          propertyTitle: _propertyDetail?['title']?.toString(),
        ),
        onEditProperty: (property) => _openListingFlow(
          property: property,
          returnNav: 'Property Details',
        ),
      );
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

  Widget _buildPendingVerificationDashboard({bool isDesktop = false}) {
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
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(context).padding.bottom + (isDesktop ? 32 : 120)),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _grey.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
        border: Border.all(color: _grey.withValues(alpha: 0.1)),
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
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1100
          ? _buildDesktopPortal()
          : _buildMobilePortal(),
    );
  }

  Widget _buildMobilePortal() {
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

  // ─── Desktop Portal ──────────────────────────────────────────────────────────

  Widget _buildDesktopPortal() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: _surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _green.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsFill.buildings,
                                color: _green,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 88,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(44),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDesktopNavItem(
                                  PhosphorIconsRegular.house, 'Dashboard'),
                              const SizedBox(height: 16),
                              _buildDesktopNavItem(
                                  PhosphorIconsRegular.buildings, 'Properties'),
                              const SizedBox(height: 16),
                              _buildDesktopNavItem(
                                  PhosphorIconsRegular.calendarCheck,
                                  'Bookings'),
                              const SizedBox(height: 16),
                              _buildDesktopNavItem(
                                  PhosphorIconsRegular.chatTeardrop,
                                  'Messages'),
                              const SizedBox(height: 16),
                              _buildDesktopNavItem(
                                  PhosphorIconsRegular.user, 'Settings',
                                  displayLabel: 'Profile'),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _grey.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.025),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Text(
                                'StayNest',
                                style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _grey.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.025),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Text(
                                _selectedNav == 'Settings'
                                    ? 'Profile'
                                    : _selectedNav,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: _dark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _grey.withValues(alpha: 0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  FilledButton.icon(
                                    onPressed: _openListingFlow,
                                    icon: const Icon(
                                      PhosphorIconsRegular.plus,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Add Property',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    tooltip: 'Notifications',
                                    onPressed: _toggleDesktopNotifications,
                                    icon: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          _showDesktopNotifications
                                              ? PhosphorIconsFill.bell
                                              : PhosphorIconsRegular.bell,
                                          color: _showDesktopNotifications
                                              ? _green
                                              : _dark,
                                          size: 20,
                                        ),
                                        if (_unreadNotificationCount > 0)
                                          Positioned(
                                            top: -5,
                                            right: -7,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 16,
                                              ),
                                              height: 16,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                              ),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFDC4C3E),
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(9),
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                _unreadNotificationCount > 9
                                                    ? '9+'
                                                    : '$_unreadNotificationCount',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Switch to Tenant Portal',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: widget.onSwitchToTenantPortal,
                                        child: ClipOval(
                                          child: AppSession.buildAvatar(
                                            AppSession.displayAvatar,
                                            width: 34,
                                            height: 34,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxContentWidth = switch (_selectedNav) {
                                'Bookings' => 1180.0,
                                'Settings' => 1080.0,
                                _ => 1480.0,
                              };
                              final contentWidth =
                                  constraints.maxWidth < maxContentWidth
                                      ? constraints.maxWidth
                                      : maxContentWidth;
                              return Center(
                                child: SizedBox(
                                  width: contentWidth,
                                  height: constraints.maxHeight,
                                  child: RefreshIndicator(
                                    onRefresh: refreshAll,
                                    color: _green,
                                    backgroundColor: _surface,
                                    child: _buildBodyContent(isDesktop: true),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showDesktopNotifications)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _showDesktopNotifications = false),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
            if (_showDesktopNotifications)
              Positioned(
                top: 92,
                right: 56,
                width: 380,
                height: 560,
                child: Material(
                  elevation: 20,
                  color: _surface,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: BorderRadius.circular(24),
                  child: NotificationsView(
                    onClose: () =>
                        setState(() => _showDesktopNotifications = false),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Changed to icon-only circular pill elements to match the new floating layout
  Widget _buildDesktopNavItem(IconData icon, String routeLabel,
      {String? displayLabel}) {
    final isActive = _selectedNav == routeLabel;
    final String labelToShow = displayLabel ?? routeLabel;

    return Tooltip(
      message: labelToShow,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            if (routeLabel == 'Messages') {
              _openMessagesModal();
              return;
            }
            setState(() => _selectedNav = routeLabel);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive ? _green : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : _grey,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Mobile Navigation Bar ─────────────────────────────────────────────────────────

  Widget _buildSolidBottomNav() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(40), // Perfect pill shape
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
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
          color: isActive ? _green.withValues(alpha: 0.1) : Colors.transparent,
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
