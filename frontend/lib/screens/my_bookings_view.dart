import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme

class BookingWrapper {
  final Property property;
  final String dateTime;
  final String checkOut;
  final String status;
  final String bookingId;
  final Map<String, dynamic> rawData;

  BookingWrapper({
    required this.property,
    required this.dateTime,
    this.checkOut = '',
    required this.status,
    required this.bookingId,
    required this.rawData,
  });
}

class MyBookingsViewScreen extends StatefulWidget {
  final VoidCallback onBack;

  const MyBookingsViewScreen({super.key, required this.onBack});

  @override
  State<MyBookingsViewScreen> createState() => _MyBookingsViewScreenState();
}

class _MyBookingsViewScreenState extends State<MyBookingsViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Completed', 'Cancelled'];

  // Status Pill Colors mapped to the minimal Theme
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFEEF2FF), // Soft Blue BG
      'text': Color(0xFF3B82F6), // Deep Blue Text
    },
    'Completed': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF059669), // Deep Green Text
    },
    'Cancelled': {
      'bg': Color(0xFFFEF2F2), // Soft Red BG
      'text': Color(0xFFEF4444), // Deep Red Text
    },
  };

  bool _isLoading = true;
  bool _hasError = false;
  List<BookingWrapper> _allBookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final rows = await BookingService.fetchBookings();
      final loaded = rows.whereType<Map>().map((raw) {
        final booking = Map<String, dynamic>.from(raw);
        final propertyPayload = booking['property'] is Map
            ? Map<String, dynamic>.from(booking['property'] as Map)
            : booking;
        final propertyImages = propertyPayload['images'] is List
            ? List<String>.from(propertyPayload['images'] as List)
            : <String>[];
        final propertyImage = propertyImages.isNotEmpty
            ? propertyImages.first
            : (propertyPayload['image_url'] ??
                    propertyPayload['image'] ??
                    booking['property_image'] ??
                    '')
                .toString();
        
        final status = booking['status']?.toString().toLowerCase() ?? '';
        final uiStatus = status == 'completed'
            ? 'Completed'
            : (status == 'cancelled' || status == 'rejected')
                ? 'Cancelled'
                : 'Upcoming';

        final checkIn = DateTime.tryParse(booking['check_in_date']?.toString() ?? '');
        final checkOut = DateTime.tryParse(booking['check_out_date']?.toString() ?? '');

        return BookingWrapper(
          property: Property(
            id: booking['property_id']?.toString() ?? '',
            name: (propertyPayload['title'] ?? propertyPayload['name'] ?? booking['property_name'] ?? 'Unknown Property').toString(),
            location: (propertyPayload['city'] ?? propertyPayload['location'] ?? booking['property_city'] ?? 'See details').toString(),
            image: propertyImage,
            images: propertyImages,
            price: int.tryParse(booking['total_price']?.toString() ?? '') ?? 0,
            lat: 0, lng: 0, rating: 0, reviews: 0, category: '',
            features: const PropertyFeatures(beds: 0, rooms: 0, baths: 0, furnished: false),
            amenities: const [],
            agent: const Agent(userId: '', name: '', avatar: ''),
            description: '',
          ),
          dateTime: checkIn == null ? 'Date unavailable' : '${_monthName(checkIn.month)} ${checkIn.day}, ${checkIn.year}',
          checkOut: checkOut == null ? '' : '${_monthName(checkOut.month)} ${checkOut.day}, ${checkOut.year}',
          status: uiStatus,
          bookingId: booking['id']?.toString() ?? '',
          rawData: booking,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _allBookings = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _monthName(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month.clamp(1, 12)];
  }

  List<BookingWrapper> get _filteredBookings {
    return _allBookings.where((b) => b.status == _selectedTab).toList();
  }

  // ─── UI BUILDERS ────────────────────────────────────────────────────────────

  Widget _buildTab(String label) {
    final bool isActive = _selectedTab == label;

    return GestureDetector(
      onTap: () {
        if (_selectedTab == label) return;
        setState(() => _selectedTab = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _tenantPrimary : _surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive ? _tenantPrimary : _grey.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? _surface : _dark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _grey.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey.shade200,
                      highlightColor: Colors.grey.shade100,
                      child: Container(
                        width: 130,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                              child: Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            ),
                            const SizedBox(height: 8),
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                              child: Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            ),
                            const Spacer(),
                            Shimmer.fromColors(
                              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                              child: Container(width: 140, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.calendarSlash, size: 48, color: _grey),
            ),
            const SizedBox(height: 24),
            Text(
              'No ${_selectedTab.toLowerCase()} bookings',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reservations will appear here once confirmed by the host.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SliverToBoxAdapter(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text('Something went wrong', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 8),
              Text('We couldn\'t load your bookings right now.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadBookings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tenantPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('Try Again', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingWrapper booking) {
    final statusColor = statusColors[booking.status]?['text'] ?? const Color(0xFF3B82F6);
    final statusBg = statusColors[booking.status]?['bg'] ?? const Color(0xFFEEF2FF);

    return Container(
      height: 140, 
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Flush Image on the left
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            child: buildPropertyImage(
              booking.property.image,
              width: 130,
              height: double.infinity,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 130,
                height: double.infinity,
                color: _grey.withOpacity(0.1),
                child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 32),
              ),
            ),
          ),

          // Details on the right
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          booking.property.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(PhosphorIconsFill.heart, color: Color(0xFFEC4899), size: 18),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(PhosphorIconsRegular.mapPin, size: 12, color: _grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          booking.property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.checkOut.isNotEmpty ? 'Dates' : 'Check-in',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking.checkOut.isNotEmpty ? '${booking.dateTime} - ${booking.checkOut}' : booking.dateTime,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          booking.status,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _slideAnim.drive(Tween<double>(begin: 0.98, end: 1.0)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                // ─── Desktop Split Layout ───
                if (isDesktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed Left Panel for Tabs and Header
                      SizedBox(
                        width: 320,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Bookings',
                                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -1.0),
                              ),
                              const SizedBox(height: 32),
                              ..._tabs.map((tab) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SizedBox(width: double.infinity, child: _buildTab(tab)),
                                  )),
                            ],
                          ),
                        ),
                      ),
                      // Scrollable Right Panel for Content
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 32)),
                            if (_isLoading)
                              _buildShimmerLoading()
                            else if (_hasError)
                              _buildErrorState()
                            else if (_filteredBookings.isEmpty)
                              _buildEmptyState()
                            else
                              SliverPadding(
                                padding: EdgeInsets.only(right: 32, bottom: MediaQuery.of(context).padding.bottom + 100),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 20),
                                        child: _buildBookingCard(_filteredBookings[index]),
                                      );
                                    },
                                    childCount: _filteredBookings.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // ─── Mobile Layout ───
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onBack,
                              behavior: HitTestBehavior.opaque,
                              child: const Icon(PhosphorIconsRegular.caretLeft, size: 28, color: _dark),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'My Bookings',
                              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _tabs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _buildTab(_tabs[index]),
                            );
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    if (_isLoading)
                      _buildShimmerLoading()
                    else if (_hasError)
                      _buildErrorState()
                    else if (_filteredBookings.isEmpty)
                      _buildEmptyState()
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _buildBookingCard(_filteredBookings[index]),
                              );
                            },
                            childCount: _filteredBookings.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}