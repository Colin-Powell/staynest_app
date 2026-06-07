import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/screens/dashboard/analytics_service.dart';
import 'package:property_app/services/booking_service.dart';
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

  @override
  void initState() {
    super.initState();
    _property = Map<String, dynamic>.from(widget.property);
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final id = _property['id']?.toString() ?? '';
    if (id.isEmpty) return;

    AnalyticsService.trackOwnerPropertyImpression(id);
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        AnalyticsService.getPropertyManagementData(id),
        BookingService.fetchBookings(isLandlord: true),
        AnalyticsService.getPropertyAvailability(id),
      ]);

      final data = results[0] as Map<String, dynamic>?;
      final landlordBookings = results[1] as List<dynamic>?;
      final blocked = results[2] as List<int>?;

      if (mounted && data != null) {
        setState(() {
          _stats = {
            'views': data['stats']?['views']?.toString() ?? '0',
            'chats': data['stats']?['chats']?.toString() ?? '0',
            'pending': data['stats']?['booking_requested']?.toString() ?? '0',
            'saves': data['stats']?['saves']?.toString() ?? '0',
          };
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
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
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
                    backgroundColor: textDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
      builder: (context) => AlertDialog(
        title: Text('Remove Property?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
        content: Text(
            'This will permanently remove this listing from the platform.',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final success =
                  await AnalyticsService.deleteProperty(_property['id']);
              if (success && mounted) {
                Navigator.pop(
                    context, true); // Return true to parent to refresh list
              } else if (mounted) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Failed to delete property.')));
              }
            },
            child: const Text('Remove',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
      _fetchInitialData(); // Refresh list
    }
  }

  void _showStatusPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildStatusOption('Available', primaryGreen),
          _buildStatusOption('Pending booking', Colors.orange),
          _buildStatusOption('Fully booked', Colors.blue),
          _buildStatusOption('Rented', textLight),
          _buildStatusOption('Under maintenance', Colors.redAccent),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 440, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildPropertyImage(
                    (_property['image_url'] ?? _property['image'] ?? '')
                        as String,
                    fit: BoxFit.cover,
                  ),
                  // Top Gradient for Navigation Legibility
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Colors.black38, Colors.transparent],
                      ),
                    ),
                  ),
                  if (_isPreviewMode)
                    Positioned(
                      top: 100,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: primaryGreen,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('PREVIEWING AS TENANT',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 2. Floating Content Detail Sheet (Overlaps the image)
            Container(
              margin: const EdgeInsets.only(top: 400), // Overlap offset
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -10),
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _isLoading
                      ? [
                          const Center(
                              child: CircularProgressIndicator(
                                  color: primaryGreen))
                        ]
                      : [
                          _buildHealthTag(),
                          const SizedBox(height: 8),
                          _buildHeaderSection(),
                          const SizedBox(height: 24),
                          _buildQuickActionShortcuts(),
                          const Divider(height: 48, color: Color(0xFFF3F4F6)),
                          _buildQuickSnapshot(),
                          const SizedBox(height: 40),
                          _buildBookingActionPanel(),
                          const SizedBox(height: 40),
                          _buildAvailabilityPreview(),
                          const SizedBox(height: 40),
                          _buildHotLeadsSection(),
                          const SizedBox(height: 40),
                          _buildLiveActivityFeed(),
                          const SizedBox(height: 40),
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

            // 3. Navigation Controls
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.shareNetwork(),
                          color: Colors.white, size: 26),
                      onPressed: () {
                        AnalyticsService.trackPropertyShare(
                            _property['id']?.toString() ?? '');
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Listing link copied to clipboard.')));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _showStatusPicker,
              child: _StatusBadge(
                  status: (_property['status'] ?? 'Available') as String),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(PhosphorIcons.mapPin(), size: 18, color: textLight),
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
      ],
    );
  }

  Widget _buildHealthTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: _healthStatus == 'UNDERPERFORMING'
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8)),
      child: Text(
          _healthStatus == 'UNDERPERFORMING'
              ? '📉 Underperfoming'
              : '🚀 Trending',
          style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _healthStatus == 'UNDERPERFORMING'
                  ? Colors.redAccent
                  : primaryGreen,
              letterSpacing: 1)),
    );
  }

  Widget _buildQuickActionShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ShortcutIcon(
            icon: PhosphorIcons.pencilLine(),
            label: 'Edit',
            onTap: () => Navigator.pushNamed(context, '/list_property',
                arguments: _property),
          ),
          _ShortcutIcon(
              icon: PhosphorIcons.usersThree(),
              label: 'Bookings',
              onTap: () => Navigator.pushNamed(context, '/landlord_bookings')),
          _ShortcutIcon(
              icon: _isPreviewMode
                  ? PhosphorIcons.eyeSlash()
                  : PhosphorIcons.eye(),
              label: _isPreviewMode ? 'Exit Preview' : 'Tenant View',
              onTap: () => setState(() => _isPreviewMode = !_isPreviewMode)),
          _ShortcutIcon(
            icon: PhosphorIcons.shareNetwork(),
            label: 'Share',
            onTap: () {
              AnalyticsService.trackPropertyShare(
                  _property['id']?.toString() ?? '');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Listing link copied to clipboard.')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSnapshot() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Snapshot (7d)',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
        const SizedBox(height: 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No pending booking requests.',
                style: GoogleFonts.poppins(color: textLight, fontSize: 14)),
          )
        else
          ..._bookings.map((booking) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3F4F6))),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                            backgroundImage: NetworkImage(
                                booking['tenant_avatar'] ??
                                    'https://i.pravatar.cc/150')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking['tenant_name'] ?? 'Guest',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        color: textDark)),
                                Text(
                                    '${booking['check_in']} - ${booking['check_out']}',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: textLight)),
                              ]),
                        ),
                        Text('Kes. ${booking['total_price']}',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800, color: textDark)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => _handleBookingRequest(
                                    booking['id'], 'Rejected'),
                                child: Text('Reject',
                                    style: GoogleFonts.poppins(
                                        color: Colors.redAccent)))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: ElevatedButton(
                                onPressed: () => _handleBookingRequest(
                                    booking['id'], 'Accepted'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryGreen),
                                child: Text('Accept',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white)))),
                      ],
                    )
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildAvailabilityPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Availability Preview',
                style: GoogleFonts.poppins(
                    fontSize: 18,
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
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            itemBuilder: (context, index) {
              final bool isBlocked = _blockedDays
                  .contains(DateTime.now().add(Duration(days: index)).day);
              return Container(
                width: 45,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isBlocked
                      ? Colors.redAccent.withOpacity(0.1)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isBlocked
                          ? Colors.redAccent.withOpacity(0.2)
                          : primaryGreen.withOpacity(0.2)),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${DateTime.now().add(Duration(days: index)).day}',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color:
                                  isBlocked ? Colors.redAccent : primaryGreen)),
                      Text(
                          [
                            'S',
                            'M',
                            'T',
                            'W',
                            'T',
                            'F',
                            'S'
                          ][(DateTime.now().add(Duration(days: index)).weekday -
                                  1) %
                              7],
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color:
                                  isBlocked ? Colors.redAccent : primaryGreen)),
                    ]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHotLeadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hot Leads',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
              children: _leads.isEmpty
                  ? [
                      Text('No high-intent leads yet.',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: textLight))
                    ]
                  : _leads
                      .map((lead) => _LeadAvatar(
                          name: lead['name'],
                          action: '${lead['interaction_count']} views',
                          image: lead['avatar'] ?? 'https://i.pravatar.cc/150'))
                      .toList()),
        ),
      ],
    );
  }

  Widget _buildLiveActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live Activity',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
        const SizedBox(height: 16),
        ..._activity.map((act) => _ActivityRow(
            icon: act['type'] == 'property_view'
                ? PhosphorIcons.eye()
                : PhosphorIcons.heart(),
            text:
                'Property ${act['type'].replaceAll('property_', '')} interaction',
            time: 'Recently')),
      ],
    );
  }

  Widget _buildBoostBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF065F46), Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.fill),
                  color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Boost Listing',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text('Current Status: Not Boosted',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9))),
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
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text('Get More Views',
                  style: GoogleFonts.poppins(
                      color: primaryGreen, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String label, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color, size: 12),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, color: textDark)),
      onTap: () async {
        final success =
            await AnalyticsService.updatePropertyStatus(_property['id'], label);
        if (success && mounted) {
          setState(() => _property['status'] = label);
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

class _ShortcutIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShortcutIcon(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6))),
        child: Row(children: [
          Icon(icon,
              size: 20, color: _LandlordPropertyManagementPageState.textDark),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
        Icon(icon,
            color: _LandlordPropertyManagementPageState.primaryGreen, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _LandlordPropertyManagementPageState.textDark)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _LandlordPropertyManagementPageState.textLight)),
      ],
    );
  }
}

class _LeadAvatar extends StatelessWidget {
  final String name, action, image;
  const _LeadAvatar(
      {required this.name, required this.action, required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundImage: NetworkImage(image)),
          const SizedBox(height: 8),
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
          Icon(icon,
              size: 18, color: _LandlordPropertyManagementPageState.textLight),
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
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(14),
      ),
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
