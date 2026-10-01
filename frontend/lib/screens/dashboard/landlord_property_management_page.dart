import 'package:flutter/material.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/screens/dashboard/landlord_dashboard_service.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'boost_listing_modal.dart';
import 'landlord_calendar_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordPropertyManagementPage extends StatefulWidget {
  final Map<String, dynamic> property;

  const LandlordPropertyManagementPage({super.key, required this.property});

  @override
  State<LandlordPropertyManagementPage> createState() =>
      _LandlordPropertyManagementPageState();
}

class _LandlordPropertyManagementPageState
    extends State<LandlordPropertyManagementPage> {
  late Map<String, dynamic> _property;
  bool _isPreviewMode = false;
  bool _isLoading = true;
  bool _activeBoost = false;

  // Wired State
  Map<String, String> _stats = {
    'views': '0',
    'chats': '0',
    'pending': '0',
    'saves': '0'
  };
  List<dynamic> _bookings = [];
  List<dynamic> _activity = [];
  List<dynamic> _leads = [];
  List<int> _blockedDays = [];
  String _healthStatus = 'HEALTHY';

  final PageController _bookingPageController =
      PageController(viewportFraction: 0.93);

  @override
  void initState() {
    super.initState();
    // Instantly use provided data for zero wait time
    _property = Map<String, dynamic>.from(widget.property);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _bookingPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    final id = (_property['id'] ?? _property['propertyId'] ?? '').toString();
    if (id.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        LandlordDashboardService.getPropertyManagementData(id),
        BookingService.fetchBookings(isLandlord: true),
        LandlordDashboardService.getPropertyAvailability(id),
        PropertiesApi.getActivePromotions(),
      ]);

      final data = results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic>
          : null;
      final landlordBookings = results[1] is List ? results[1] as List : null;
      final blocked = results[2] is List<int> ? results[2] as List<int> : null;
      final promos = results[3] is List ? results[3] as List : [];
      final isBoosted = promos.any((p) => p['property_id'].toString() == id);

      if (mounted && data != null) {
        setState(() {
          _activeBoost = isBoosted;
          _stats = {
            'views': data['stats']?['views']?.toString() ?? '0',
            'chats': data['stats']?['chats']?.toString() ?? '0',
            'pending': data['stats']?['booking_requested']?.toString() ?? '0',
            'saves': data['stats']?['saves']?.toString() ?? '0',
          };

          if ((_property['title'] == null || _property['title'] == '') &&
              data['property'] != null &&
              data['property'] is Map) {
            _property.addAll(Map<String, dynamic>.from(data['property']));
          }

          _healthStatus = data['health'] ?? 'HEALTHY';
          _activity = data['activity'] ?? [];
          _leads = data['leads'] ?? [];
          _bookings = landlordBookings
                  ?.where(
                      (b) => b['property_id'] == id && b['status'] == 'pending')
                  .toList() ??
              [];
          _blockedDays = blocked ?? [];
        });
      }
    } catch (e) {
      debugPrint("Live data sync failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Modals & Dialogs ───────────────────────────────────────────────────────

  void _showActionSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.1), shape: BoxShape.circle),
              child:
                  const Icon(PhosphorIconsBold.check, color: _green, size: 48),
            ),
            const SizedBox(height: 24),
            Text('Success!',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: _grey, fontWeight: FontWeight.w400)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                    elevation: 0),
                child: Text('Continue',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: _surface)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove Property?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: _dark,
                letterSpacing: -0.5)),
        content: Text(
            'This will permanently remove this listing from the platform.',
            style: GoogleFonts.poppins(color: _grey, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: _dark, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final success = await LandlordDashboardService.deleteProperty(
                  _property['id']);
              if (success && mounted) {
                Navigator.pop(context, true);
              } else if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to delete property.')));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: Text('Remove',
                style: GoogleFonts.poppins(
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBookingRequest(String bookingId, String action) async {
    final apiAction = action == 'Accepted' ? 'confirm' : 'reject';
    final success = await BookingService.updateStatus(bookingId, apiAction);
    if (success && mounted) {
      _showActionSuccess('Booking request successfully $action.');
      _fetchInitialData();
    }
  }

  Future<void> _openPropertyEditor() async {
    final propertyId = (_property['id'] ?? _property['propertyId'])?.toString();
    if (propertyId == null || propertyId.isEmpty) return;

    try {
      final property = await PropertiesApi.getPropertyById(propertyId);
      if (!mounted) return;
      final updated = await Navigator.pushNamed<bool>(
        context,
        '/list_property',
        arguments: property,
      );
      if (updated == true && mounted) {
        final refreshedProperty =
            await PropertiesApi.getPropertyById(propertyId);
        if (!mounted) return;
        setState(() => _property.addAll(refreshedProperty));
        await _fetchInitialData();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load property for editing: $error')),
      );
    }
  }

  void _showStatusPicker() async {
    showResponsiveModalSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            _buildStatusOption('Available', _green),
            _buildStatusOption('Pending booking', const Color(0xFFF59E0B)),
            _buildStatusOption('Fully booked', const Color(0xFF3B82F6)),
            _buildStatusOption(
                'Temporarily unavailable', const Color(0xFF64748B)),
            _buildStatusOption('Rented', _grey),
            _buildStatusOption('Under maintenance', const Color(0xFFEF4444)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<bool> _showStatusConfirmationDialog(String status) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Mark as $status?',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    letterSpacing: -0.5)),
            content: Text(
                'This will update the availability shown to tenants and prevent new booking requests. Are you sure?',
                style: GoogleFonts.poppins(color: _grey, fontSize: 14)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(
                          color: _dark, fontWeight: FontWeight.w600))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: Text('Confirm',
                    style: GoogleFonts.poppins(
                        color: _surface, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildStatusOption(String label, Color color) {
    return ListTile(
      leading: Icon(PhosphorIconsFill.circle, color: color, size: 16),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, color: _dark, fontSize: 15)),
      onTap: () async {
        if (label == 'Rented' || label == 'Temporarily unavailable') {
          final confirmed = await _showStatusConfirmationDialog(label);
          if (!confirmed) return;
        }

        final statusCode = {
          'Available': 'available',
          'Pending booking': 'pending_booking',
          'Fully booked': 'fully_booked',
          'Temporarily unavailable': 'unavailable',
          'Rented': 'rented',
          'Under maintenance': 'maintenance',
        }[label];
        if (statusCode == null) return;

        final propertyId =
            (_property['id'] ?? _property['propertyId'])?.toString();
        if (propertyId == null || propertyId.isEmpty) return;

        final success = await LandlordDashboardService.updatePropertyStatus(
            propertyId, statusCode);
        if (success && mounted) {
          setState(() => _property['availability_status'] = statusCode);
          _showActionSuccess('Property status updated to $label.');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to update property status to $label.')),
          );
        }
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // The scrollable background
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Premium Hero Image Sliver ───
          SliverAppBar(
            expandedHeight: 340.0,
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                      color: _surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10)
                      ]),
                  child: const Icon(PhosphorIconsRegular.caretLeft,
                      color: _dark, size: 20),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () async {
                    final propertyId = _property['id']?.toString() ?? '';
                    final link = 'https://staynest.top/properties/$propertyId';
                    await Share.share(
                        '${_property['title'] ?? 'StayNest property'}: $link');
                    await AnalyticsService.trackPropertyShare(propertyId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Listing shared.')));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10)
                        ]),
                    child: const Icon(PhosphorIconsRegular.shareNetwork,
                        color: _dark, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  buildPropertyImage(
                    (_property['image_url'] ?? _property['image'] ?? '')
                        .toString(),
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient at the top so the white buttons are always visible
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent
                        ],
                        stops: const [0.0, 0.3],
                      ),
                    ),
                  ),
                  // The rounded overlapping background curve at the bottom of the image
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    height: 32,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: _bg,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                    ),
                  ),
                  if (_isPreviewMode)
                    Positioned(
                      bottom: 40,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          'PREVIEWING AS TENANT',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Main Content Scrolling Above Image ───
          SliverToBoxAdapter(
            child: Container(
              color: _bg, // Ensures seamless scroll continuation
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, MediaQuery.of(context).padding.bottom + 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instantly render core info
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  _buildQuickActionShortcuts(),
                  const SizedBox(height: 32),

                  // Render API-dependent sections (will show shimmer if loading)
                  _buildQuickSnapshot(),
                  const SizedBox(height: 32),
                  _buildBookingActionPanel(),
                  const SizedBox(height: 32),
                  _buildAvailabilityPreview(),
                  const SizedBox(height: 32),
                  _buildHotLeadsSection(),
                  const SizedBox(height: 32),
                  _buildLiveActivityFeed(),
                  const SizedBox(height: 32),
                  _buildBoostBanner(),
                  const SizedBox(height: 48),

                  Center(
                    child: TextButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(PhosphorIconsRegular.trash,
                          color: Color(0xFFEF4444), size: 20),
                      label: Text(
                        'Remove Property from Portfolio',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
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

  // ─── Sections ─────────────────────────────────────────────────────────────

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _property['title'] ?? 'Property Name',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _isLoading
                ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade100,
                    child: Container(
                        width: 80,
                        height: 28,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12))),
                  )
                : _buildHealthTag(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(PhosphorIconsFill.mapPin, size: 16, color: _grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                (_property['city'] ?? _property['location'] ?? 'Location')
                    .toString(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _grey,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _showStatusPicker,
          child: _StatusBadge(
            status: {
                  'available': 'Available',
                  'pending_booking': 'Pending booking',
                  'fully_booked': 'Fully booked',
                  'unavailable': 'Temporarily unavailable',
                  'rented': 'Rented',
                  'maintenance': 'Under maintenance',
                }[_property['availability_status']?.toString().toLowerCase()] ??
                'Available',
          ),
        ),
      ],
    );
  }

  Widget _buildHealthTag() {
    final isHealthy = _healthStatus != 'UNDERPERFORMING';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHealthy ? _green.withOpacity(0.1) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy ? PhosphorIconsBold.trendUp : PhosphorIconsBold.trendDown,
            size: 14,
            color: isHealthy ? _green : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 6),
          Text(
            isHealthy ? 'Trending' : 'Needs Work',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isHealthy ? _green : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _ShortcutPill(
            icon: PhosphorIconsRegular.pencilLine,
            label: 'Edit',
            onTap: _openPropertyEditor,
          ),
          _ShortcutPill(
            icon: PhosphorIconsRegular.usersThree,
            label: 'Bookings',
            onTap: () => Navigator.pushNamed(context, '/landlord_bookings'),
          ),
          _ShortcutPill(
            icon: _isPreviewMode
                ? PhosphorIconsRegular.eyeSlash
                : PhosphorIconsRegular.eye,
            label: _isPreviewMode ? 'Exit Preview' : 'Tenant View',
            isActive: _isPreviewMode,
            onTap: () => setState(() => _isPreviewMode = !_isPreviewMode),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSnapshot() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Snapshot (7d)',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 20),
          _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                      4,
                      (index) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade100,
                            child: Column(
                              children: [
                                Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle)),
                                const SizedBox(height: 8),
                                Container(
                                    width: 30,
                                    height: 16,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(4))),
                              ],
                            ),
                          )),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CompactStat(
                        label: 'Views',
                        value: _stats['views']!,
                        icon: PhosphorIconsRegular.eye),
                    _CompactStat(
                        label: 'Chats',
                        value: _stats['chats']!,
                        icon: PhosphorIconsRegular.chatCircleText),
                    _CompactStat(
                        label: 'Pending',
                        value: _stats['pending']!,
                        icon: PhosphorIconsRegular.calendarCheck),
                    _CompactStat(
                        label: 'Saves',
                        value: _stats['saves']!,
                        icon: PhosphorIconsRegular.heart),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildBookingActionPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Booking Requests',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/landlord_bookings'),
              child: Text('View all',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          _buildCardWrapper(
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Container(
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
            ),
          )
        else if (_bookings.isEmpty)
          _buildCardWrapper(
            child: Row(
              children: [
                const Icon(PhosphorIconsRegular.calendarBlank,
                    color: _grey, size: 28),
                const SizedBox(width: 16),
                Text('No pending booking requests.',
                    style: GoogleFonts.poppins(
                        color: _grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          )
        else
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _bookingPageController,
              physics: const BouncingScrollPhysics(),
              padEnds: false,
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _buildCardWrapper(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: _grey.withOpacity(0.1))),
                              child: ClipOval(
                                  child: AppSession.buildAvatar(
                                      booking['tenant_avatar'],
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking['tenant_name'] ?? 'Guest',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: _dark,
                                          fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '${booking['check_in']} - ${booking['check_out']}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: _grey)),
                                ],
                              ),
                            ),
                            Text('Ksh. ${booking['total_price']}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700, color: _dark)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => _handleBookingRequest(
                                    booking['id'], 'Rejected'),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  backgroundColor: const Color(0xFFFEF2F2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Reject',
                                    style: GoogleFonts.poppins(
                                        color: const Color(0xFFEF4444),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleBookingRequest(
                                    booking['id'], 'Accepted'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Accept',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAvailabilityPreview() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Availability',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    LandlordCalendarPage.route(
                        propertyId: _property['id'],
                        propertyTitle: _property['title'] ?? '')),
                child: Text('Full Calendar',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _green)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: _isLoading
                ? ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey.shade200,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                            width: 48,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: 14,
                    itemBuilder: (context, index) {
                      final date = DateTime.now().add(Duration(days: index));
                      final dateKey =
                          date.year * 10000 + date.month * 100 + date.day;
                      final bool isBlocked = _blockedDays.contains(dateKey);
                      return Container(
                        width: 48,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: isBlocked ? const Color(0xFFFEF2F2) : _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isBlocked
                                  ? const Color(0xFFFCA5A5)
                                  : _grey.withOpacity(0.2),
                              width: 1.5),
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${date.day}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isBlocked
                                          ? const Color(0xFFEF4444)
                                          : _dark)),
                              Text(
                                  [
                                    'S',
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S'
                                  ][(date.weekday - 1) % 7],
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isBlocked
                                          ? const Color(0xFFEF4444)
                                          : _grey)),
                            ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotLeadsSection() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hot Leads',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: _isLoading
                ? Row(
                    children: List.generate(
                        4,
                        (index) => Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle)),
                              ),
                            )),
                  )
                : Row(
                    children: _leads.isEmpty
                        ? [
                            Text('No high-intent leads yet.',
                                style: GoogleFonts.poppins(
                                    fontSize: 13, color: _grey))
                          ]
                        : _leads
                            .map((lead) => _LeadAvatar(
                                name: lead['name'],
                                action: '${lead['interaction_count']} views',
                                image: lead['avatar']))
                            .toList()),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActivityFeed() {
    return _buildCardWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Activity',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 16),
          if (_isLoading)
            Column(
              children: List.generate(
                  2,
                  (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle))),
                            const SizedBox(width: 12),
                            Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                    width: 150,
                                    height: 14,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(4)))),
                          ],
                        ),
                      )),
            )
          else if (_activity.isEmpty)
            Text('No recent activity.',
                style: GoogleFonts.poppins(fontSize: 13, color: _grey))
          else
            ..._activity.take(4).map((act) => _ActivityRow(
                icon: act['type'] == 'property_view'
                    ? PhosphorIconsRegular.eye
                    : PhosphorIconsRegular.heart,
                text:
                    'Property ${act['type'].replaceAll('property_', '')} interaction',
                time: 'Recently')),
        ],
      ),
    );
  }

  Widget _buildBoostBanner() {
    if (_isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(24))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _activeBoost
            ? const Color(0xFFFDF4FF)
            : _surface, // Soft purple if active
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: _activeBoost
                ? const Color(0xFFE879F9)
                : _grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _activeBoost
                        ? const Color(0xFFF0ABFC).withOpacity(0.2)
                        : _green.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(
                    _activeBoost
                        ? PhosphorIconsFill.rocketLaunch
                        : PhosphorIconsFill.megaphone,
                    color: _activeBoost ? const Color(0xFFC026D3) : _green,
                    size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_activeBoost ? 'Boost Active' : 'Boost Listing',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                      Text(
                          _activeBoost
                              ? 'Your property is currently promoted.'
                              : 'Get seen by 5x more tenants.',
                          style:
                              GoogleFonts.poppins(fontSize: 13, color: _grey)),
                    ]),
              ),
            ],
          ),
          if (!_activeBoost) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await BoostListingModal.show(
                      context, _property['id'].toString());
                  if (result == true) {
                    _fetchInitialData();
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32))),
                child: Text('Boost Now',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // Helper for consistent cards
  Widget _buildCardWrapper({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }
}

// ─── INTERNAL COMPONENTS ─────────────────────────────────────────────────────

class _ShortcutPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ShortcutPill(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: isActive ? _green : _surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: isActive ? _green : _grey.withOpacity(0.2), width: 1.5)),
        child: Row(children: [
          Icon(icon, size: 18, color: isActive ? _surface : _dark),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? _surface : _dark)),
        ]),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _CompactStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _green.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: _green, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w500, color: _grey)),
      ],
    );
  }
}

class _LeadAvatar extends StatelessWidget {
  final String name;
  final String action;
  final String? image;
  const _LeadAvatar(
      {required this.name, required this.action, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _grey.withOpacity(0.2))),
            child: ClipOval(
                child: AppSession.buildAvatar(image,
                    width: 56, height: 56, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 10),
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
          Text(action,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _green, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String text, time;
  const _ActivityRow(
      {required this.icon, required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _grey.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: _dark),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _dark,
                      fontWeight: FontWeight.w500))),
          Text(time, style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _green,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(PhosphorIconsRegular.caretDown, size: 14, color: _green),
        ],
      ),
    );
  }
}
