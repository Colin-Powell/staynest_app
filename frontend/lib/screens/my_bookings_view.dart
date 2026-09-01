// lib/screens/my_bookings_view.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/services/booking_service.dart';

/// A wrapper to attach booking-specific data to standard properties
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
      
  static const _tabs = ['Upcoming', 'Completed', 'Cancelled'];
  
  // Airbnb-style Minimalist Color Palette
  static const Color tenantPrimary = Color(0xFF3F37C9); // Tenant Blue (Used sparingly)
  static const Color textDark = Color(0xFF222222); // Dark grey/black
  static const Color textLight = Color(0xFF717171); // Light grey
  static const Color dividerColor = Color(0xFFEBEBEB);

  late final TabController _tabController;
  List<BookingWrapper> bookings = [];
  bool loading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      loading = true;
      hasError = false;
    });
    try {
      final rows = await BookingService.fetchBookings();
      final loaded = rows.whereType<Map>().map((raw) {
        final booking = Map<String, dynamic>.from(raw);
        final status = booking['status']?.toString().toLowerCase() ?? '';
        final uiStatus = status == 'completed'
            ? 'Completed'
            : (status == 'cancelled' || status == 'rejected')
                ? 'Cancelled'
                : 'Upcoming';
        final checkIn =
            DateTime.tryParse(booking['check_in_date']?.toString() ?? '');
        final checkOut =
            DateTime.tryParse(booking['check_out_date']?.toString() ?? '');
        return BookingWrapper(
          property: Property(
            id: booking['property_id']?.toString() ?? '',
            name: booking['property_name']?.toString() ?? 'Unknown Property',
            location: booking['property_city']?.toString() ?? 'See details',
            image: booking['property_image']?.toString() ?? '',
            images: const [],
            price: int.tryParse(booking['total_price']?.toString() ?? '') ?? 0,
            lat: 0,
            lng: 0,
            rating: 0,
            reviews: 0,
            category: '',
            features: const PropertyFeatures(
                beds: 0, rooms: 0, baths: 0, furnished: false),
            amenities: const [],
            agent: const Agent(userId: '', name: '', avatar: ''),
            description: '',
          ),
          dateTime: checkIn == null
              ? 'Date unavailable'
              : '${_monthName(checkIn.month)} ${checkIn.day}, ${checkIn.year}',
          checkOut: checkOut == null
              ? ''
              : '${_monthName(checkOut.month)} ${checkOut.day}, ${checkOut.year}',
          status: uiStatus,
          bookingId: booking['id']?.toString() ?? '',
          rawData: booking,
        );
      }).toList();
      if (mounted) {
        setState(() {
          bookings = loaded;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          hasError = true;
        });
      }
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month.clamp(1, 12)];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return tenantPrimary;
      case 'Completed':
        return const Color(0xFF059669); // Emerald Green
      case 'Cancelled':
        return const Color(0xFFDC2626); // Red
      default:
        return textLight;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Upcoming':
        return Icons.schedule_rounded;
      case 'Completed':
        return Icons.check_circle_outline_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Minimalist Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  _NavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: widget.onBack,
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'My Bookings',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            
            // --- Elegant Underline Tab Bar ---
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor, width: 1.5),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: textDark,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                labelColor: textDark,
                unselectedLabelColor: textLight,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),

            // --- Content Area ---
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(color: textDark))
                  : hasError
                      ? _buildErrorState()
                      : TabBarView(
                          controller: _tabController,
                          children:
                              _tabs.map((tab) => _buildTabContent(tab)).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String tab) {
    final visible = bookings.where((b) => b.status == tab).toList();
    if (visible.isEmpty) {
      return _buildEmptyState(tab);
    }
    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: textDark,
      backgroundColor: Colors.white,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (_, index) => _bookingCard(visible[index]),
      ),
    );
  }

  Widget _buildEmptyState(String tab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tab == 'Upcoming'
                ? Icons.calendar_today_rounded
                : tab == 'Completed'
                    ? Icons.task_alt_rounded
                    : Icons.block_rounded,
            size: 48,
            color: dividerColor,
          ),
          const SizedBox(height: 24),
          Text(
            'No ${tab.toLowerCase()} bookings',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tab == 'Upcoming'
                ? 'Your upcoming stays will appear here.'
                : tab == 'Completed'
                    ? 'Your past stays will show up here.'
                    : 'Cancelled bookings will appear here.',
            style: GoogleFonts.poppins(
              fontSize: 15, 
              color: textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: dividerColor),
          const SizedBox(height: 24),
          Text(
            'Something went wrong',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t load your bookings right now.',
            style: GoogleFonts.poppins(fontSize: 15, color: textLight),
          ),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: _loadBookings,
            style: OutlinedButton.styleFrom(
              foregroundColor: textDark,
              side: const BorderSide(color: textDark, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: Text('Try Again',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BookingWrapper booking) {
    final statusColor = _statusColor(booking.status);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: booking.property.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: booking.property.image,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: dividerColor,
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 40, color: textLight),
                      ),
                    )
                  : Container(
                      color: dividerColor,
                      child: const Icon(Icons.image_outlined,
                          size: 40, color: textLight),
                    ),
            ),
          ),
          
          // Card Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        booking.property.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Minimalist Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: statusColor, width: 1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(booking.status), size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            booking.status,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Location
                Text(
                  booking.property.location,
                  style: GoogleFonts.poppins(fontSize: 14, color: textLight),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1, color: dividerColor, thickness: 1.2),
                const SizedBox(height: 16),

                // Date + Price Info Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dates
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.checkOut.isNotEmpty ? 'Dates' : 'Check-in',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking.checkOut.isNotEmpty 
                              ? '${booking.dateTime} - ${booking.checkOut}'
                              : booking.dateTime,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ksh. ${booking.property.price}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Booking ID (Subtle)
                Text(
                  'Booking ID: #${booking.bookingId.substring(0, booking.bookingId.length > 8 ? 8 : booking.bookingId.length).toUpperCase()}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared UI Component ───────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}