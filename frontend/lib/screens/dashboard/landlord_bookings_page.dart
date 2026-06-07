import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

import 'landlord_booking_detail_page.dart';
import 'landlord_calendar_page.dart';

class LandlordBookingsPage extends StatefulWidget {
  const LandlordBookingsPage({super.key});

  @override
  State<LandlordBookingsPage> createState() => _LandlordBookingsPageState();
}

class _LandlordBookingsPageState extends State<LandlordBookingsPage> {
  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Completed', 'Cancelled'];

  // Design Tokens
  static const Color textDark = Color(0xFF111827);
  static const Color textMedium = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status Pill Colors mapped exactly to the PDF
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFD6E4FF), // Soft Blue BG
      'text': Color(0xFF3F37C9), // Deep Blue Text
    },
    'Completed': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF065F46), // Deep Green Text
    },
    'Cancelled': {
      'bg': Color(0xFFFEE2E2), // Soft Red BG
      'text': Color(0xFF991B1B), // Deep Red Text
    },
  };

  // Booking data management
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allBookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await BookingService.fetchBookings(isLandlord: true);

      if (!mounted) return;

      setState(() {
        _allBookings = data.map((b) {
          return {
            'id': b['id']?.toString() ?? '',
            'title':
                b['title']?.toString() ?? b['property_title']?.toString() ??
                    'Property',
            'location': b['city']?.toString() ?? '',
            'tenant_id': b['tenant_id']?.toString() ?? '',
            'tenant_name': b['tenant_name']?.toString() ?? 'Tenant',
            'date': b['check_in_date']?.toString().split('T')[0] ?? '',
            'time': '10:00 AM',
            'rawStatus': b['status']?.toString().toLowerCase() ?? '',
            'status': _mapStatus(b['status']?.toString() ?? ''),
            'image': b['image_url']?.toString() ?? '',
            'price': (double.tryParse(b['total_price']?.toString() ?? '0') ??
                    0)
                .toInt(),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bookings: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _mapStatus(String apiStatus) {
    final s = apiStatus.toLowerCase();
    if (s == 'confirmed' || s == 'pending') return 'Upcoming';
    if (s == 'completed') return 'Completed';
    if (s == 'cancelled' || s == 'rejected') return 'Cancelled';
    return 'Upcoming';
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _allBookings.where((booking) {
      final status = booking['status'] as String? ?? '';
      return status == _selectedTab;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F6EF),
      extendBody: true,
      body: Stack(
        children: [
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
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 16,
                          left: 24,
                          right: 24,
                          bottom: 24,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'My Bookings',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tabs
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _tabs
                              .map((tab) => _buildTab(tab))
                              .toList(),
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                    // Body
                    if (_errorMessage != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadBookings,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_isLoading)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          MediaQuery.of(context).padding.bottom + 160,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 32),
                                child: _buildBookingSkeletonCard(),
                              );
                            },
                            childCount: 3,
                          ),
                        ),
                      )
                    else if (_filteredBookings.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                color: textLight,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No bookings yet',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bookings will appear here when you receive reservations',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          MediaQuery.of(context).padding.bottom + 160,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final booking = _filteredBookings[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 32),
                                child: GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            LandlordBookingDetailPage(
                                          booking: booking,
                                        ),
                                      ),
                                    );
                                    if (result == true) {
                                      _loadBookings();
                                    }
                                  },
                                  child: _buildBookingCard(booking),
                                ),
                              );
                            },
                            childCount: _filteredBookings.length,
                          ),
                        ),
                      ),
                  ],
                ),

                // Floating "View Calendar" Button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 120,
                      left: 24,
                      right: 24,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context)
                            .push(LandlordCalendarPage.route()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF8DCBAA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View Calendar',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
    );
  }

  Widget _buildTab(String label) {
    final bool isActive = _selectedTab == label;

    final Color bgColor =
        isActive ? statusColors[label]!['bg']! : Colors.transparent;
    final Color textColor =
        isActive ? statusColors[label]!['text']! : textLight;
    final Color borderColor =
        isActive ? Colors.transparent : const Color(0xFFD1D5DB);

    return GestureDetector(
      onTap: () {
        if (_selectedTab == label) return;
        setState(() {
          _selectedTab = label;
          _isLoading = true;
        });
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'Upcoming';

    return _GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 140,
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(28)),
              child: buildPropertyImage(
                booking['image'] ?? '',
                width: 115,
                height: 140,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 115,
                  height: 140,
                  color: const Color(0xFFE8F6EF),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            booking['title'] ?? 'Booking',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking['location'] ?? 'Unknown location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textLight,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${booking['date'] ?? 'TBD'}   |   ${booking['time'] ?? 'TBD'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColors[status]!['bg'],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColors[status]!['text'],
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
      ),
    );
  }

  Widget _buildBookingSkeletonCard() {
    return _GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 140,
        child: Row(
          children: [
            Container(
              width: 115,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 160,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
    this.blur = 20.0,
    this.opacity = 0.55,
    this.borderWidth = 1.5,
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
