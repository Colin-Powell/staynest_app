import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';
import 'landlord_calendar_page.dart';

class LandlordPropertyManagementPage extends StatefulWidget {
  final Map<String, dynamic> property;

  const LandlordPropertyManagementPage({super.key, required this.property});

  @override
  State<LandlordPropertyManagementPage> createState() =>
      _LandlordPropertyManagementPageState();
}

class _LandlordPropertyManagementPageState
    extends State<LandlordPropertyManagementPage> {
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);

  late Map<String, dynamic> _property;
  bool _isPreviewMode = false;
  bool _isLoading = true;

  // Wired State
  Map<String, dynamic> _stats = {
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

    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        AnalyticsService.getPropertyManagementData(id),
        BookingService.fetchBookings(isLandlord: true),
        AnalyticsService.getPropertyAvailability(id),
      ]);

      final data = results[0] is Map<String, dynamic>
          ? results[0] as Map<String, dynamic>
          : null;
      final landlordBookings = results[1] is List ? results[1] as List : null;
      final blocked = results[2] is List<int> ? results[2] as List<int> : null;

      if (mounted && data != null) {
        setState(() {
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
      debugPrint('Error loading dashboard data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Success Modal Engine ---
  void _showActionSuccess(String message) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: primaryGreen, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                'Success!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text('Continue',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Remove Property?',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          content: Text(
              'This will permanently remove this listing from the platform.',
              style: GoogleFonts.poppins(color: textLight)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(
                        color: textDark, fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final success =
                    await AnalyticsService.deleteProperty(_property['id']);
                if (success && mounted) {
                  Navigator.pop(context, true);
                } else if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Failed to delete property.')));
                }
              },
              child: Text('Remove',
                  style: GoogleFonts.poppins(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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

  void _showStatusPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          _buildStatusOption('Available', primaryGreen),
          _buildStatusOption('Pending booking', Colors.orange),
          _buildStatusOption('Fully booked', Colors.blue),
          _buildStatusOption('Rented', textLight),
          _buildStatusOption('Under maintenance', Colors.redAccent),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Soft Gradient Background
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

          // 2. Fading Hero Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.6, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildPropertyImage(
                    (_property['image_url'] ?? _property['image'] ?? '')
                        .toString(),
                    fit: BoxFit.cover,
                  ),
                  if (_isPreviewMode)
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: primaryGreen.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('PREVIEWING AS TENANT',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Main Scrolling Content
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Navigation Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _GlassCircleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        _GlassCircleButton(
                          icon: PhosphorIcons.shareNetwork(),
                          onTap: () {
                            AnalyticsService.trackPropertyShare(
                                _property['id']?.toString() ?? '');
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Listing link copied to clipboard.')));
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Spacer to push content down into the faded area of the image
                const SliverToBoxAdapter(child: SizedBox(height: 200)),

                // Content
                SliverToBoxAdapter(
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: CircularProgressIndicator(color: primaryGreen),
                        ))
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderSection(),
                              const SizedBox(height: 24),
                              _buildQuickActionShortcuts(),
                              const SizedBox(height: 32),
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
                                child: TextButton(
                                  onPressed: _confirmDelete,
                                  child: Text(
                                    'Remove Property from Portfolio',
                                    style: GoogleFonts.poppins(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w700,
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
          children: [
            Expanded(
              child: Text(
                _property['title'] ?? 'Property Name',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildHealthTag(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                size: 18, color: textLight),
            const SizedBox(width: 6),
            Text(
              (_property['city'] ?? _property['location'] ?? 'Location')
                  .toString(),
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _showStatusPicker,
          child: _StatusBadge(
              status: (_property['status'] ?? 'Available') as String),
        ),
      ],
    );
  }

  Widget _buildHealthTag() {
    final isHealthy = _healthStatus != 'UNDERPERFORMING';
    return _GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: BorderRadius.circular(12),
      opacity: 0.8,
      child: Row(
        children: [
          Icon(
            isHealthy
                ? PhosphorIcons.trendUp(PhosphorIconsStyle.bold)
                : PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
            size: 14,
            color: isHealthy ? primaryGreen : Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Text(
            isHealthy ? 'Trending' : 'Needs Work',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isHealthy ? primaryGreen : Colors.redAccent,
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
            icon: PhosphorIcons.pencilLine(),
            label: 'Edit',
            onTap: () => Navigator.pushNamed(context, '/list_property',
                arguments: _property),
          ),
          _ShortcutPill(
              icon: PhosphorIcons.usersThree(),
              label: 'Bookings',
              onTap: () => Navigator.pushNamed(context, '/landlord_bookings')),
          _ShortcutPill(
              icon: _isPreviewMode
                  ? PhosphorIcons.eyeSlash()
                  : PhosphorIcons.eye(),
              label: _isPreviewMode ? 'Exit Preview' : 'Tenant View',
              onTap: () => setState(() => _isPreviewMode = !_isPreviewMode)),
        ],
      ),
    );
  }

  Widget _buildQuickSnapshot() {
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Snapshot (7d)',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CompactStat(
                  label: 'Views',
                  value: _stats['views'],
                  icon: PhosphorIcons.eye()),
              _CompactStat(
                  label: 'Chats',
                  value: _stats['chats'],
                  icon: PhosphorIcons.chatCircleText()),
              _CompactStat(
                  label: 'Pending',
                  value: _stats['pending'],
                  icon: PhosphorIcons.calendarCheck()),
              _CompactStat(
                  label: 'Saves',
                  value: _stats['saves'],
                  icon: PhosphorIcons.heart()),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textDark)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/landlord_bookings'),
              child: Text('View all',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryGreen)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_bookings.isEmpty)
          _GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(PhosphorIcons.calendarBlank(), color: textLight, size: 28),
                const SizedBox(width: 16),
                Text('No pending booking requests.',
                    style: GoogleFonts.poppins(
                        color: textLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          )
        else
          // Horizontal Pagination for Bookings
          SizedBox(
            height: 165,
            child: PageView.builder(
              controller: _bookingPageController,
              physics: const BouncingScrollPhysics(),
              padEnds: false, // Start at the edge
              itemCount: _bookings.length,
              itemBuilder: (context, index) {
                final booking = _bookings[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: _GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: AppSession.buildAvatar(
                                booking['tenant_avatar'],
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking['tenant_name'] ?? 'Guest',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: textDark,
                                          fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                      '${booking['check_in']} - ${booking['check_out']}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12, color: textLight)),
                                ],
                              ),
                            ),
                            Text('Kes. ${booking['total_price']}',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    color: primaryGreen)),
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
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Reject',
                                    style: GoogleFonts.poppins(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _handleBookingRequest(
                                    booking['id'], 'Accepted'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Accept',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
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
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Availability',
                  style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textDark)),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    LandlordCalendarPage.route(
                      propertyId: _property['id'],
                      propertyTitle: _property['title'] ?? '',
                    )),
                child: Text('Full Calendar',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 14,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final dateKey = date.year * 10000 + date.month * 100 + date.day;
                final bool isBlocked = _blockedDays.contains(dateKey);
                return Container(
                  width: 48,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isBlocked
                        ? Colors.redAccent.withOpacity(0.1)
                        : Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isBlocked
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.white,
                        width: 1.5),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${date.day}',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color:
                                    isBlocked ? Colors.redAccent : textDark)),
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
                                color:
                                    isBlocked ? Colors.redAccent : textLight)),
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
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hot Leads',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
                children: _leads.isEmpty
                    ? [
                        Text('No high-intent leads yet.',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: textLight))
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
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Activity',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800, color: textDark)),
          const SizedBox(height: 16),
          if (_activity.isEmpty)
            Text('No recent activity.',
                style: GoogleFonts.poppins(fontSize: 13, color: textLight))
          else
            ..._activity.take(4).map((act) => _ActivityRow(
                icon: act['type'] == 'property_view'
                    ? PhosphorIcons.eye()
                    : PhosphorIcons.heart(),
                text:
                    'Property ${act['type'].replaceAll('property_', '')} interaction',
                time: 'Recently')),
        ],
      ),
    );
  }

  Widget _buildBoostBanner() {
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      opacity: 0.8,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                    color: primaryGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Boost Listing',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textDark)),
                      Text('Get seen by 5x more tenants.',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: textLight)),
                    ]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: Text('Boost Now',
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showStatusConfirmationDialog(String status) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Text('Mark as $status?',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
              content: Text(
                  'This will update your occupancy metrics and hide this listing from search results. Are you sure?',
                  style: GoogleFonts.poppins(color: textLight)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('Cancel',
                        style: GoogleFonts.poppins(
                            color: textDark, fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Confirm',
                      style: GoogleFonts.poppins(
                          color: primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Widget _buildStatusOption(String label, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 14),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: textDark, fontSize: 15)),
      onTap: () async {
        if (label == 'Rented') {
          final confirmed = await _showStatusConfirmationDialog(label);
          if (!confirmed) return;
        }

        final success =
            await AnalyticsService.updatePropertyStatus(_property['id'], label);
        if (success && mounted) {
          setState(() => _property['status'] = label);
          _showActionSuccess('Property status updated to $label.');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update status.')));
        }
        Navigator.pop(context);
      },
    );
  }
}

// ─── INTERNAL COMPONENTS ─────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _ShortcutPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutPill(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 1.5)),
        child: Row(children: [
          Icon(icon,
              size: 18,
              color: _LandlordPropertyManagementPageState.primaryGreen),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _LandlordPropertyManagementPageState.textDark)),
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
            color: Colors.white.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: _LandlordPropertyManagementPageState.primaryGreen,
              size: 20),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _LandlordPropertyManagementPageState.textDark)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _LandlordPropertyManagementPageState.textLight)),
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
          ClipOval(
            child: AppSession.buildAvatar(
              image,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          Text(name,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _LandlordPropertyManagementPageState.textDark)),
          Text(action,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: _LandlordPropertyManagementPageState.primaryGreen,
                  fontWeight: FontWeight.w600)),
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
                color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
            child: Icon(icon,
                size: 16,
                color: _LandlordPropertyManagementPageState.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _LandlordPropertyManagementPageState.textDark,
                      fontWeight: FontWeight.w500))),
          Text(time,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _LandlordPropertyManagementPageState.textLight)),
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
          color: _LandlordPropertyManagementPageState.primaryGreen
              .withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _LandlordPropertyManagementPageState.primaryGreen
                  .withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _LandlordPropertyManagementPageState.primaryGreen,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _LandlordPropertyManagementPageState.primaryGreen),
        ],
      ),
    );
  }
}

// ─── Glassmorphism Core Utility ──────────────────────────────────────────────
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
