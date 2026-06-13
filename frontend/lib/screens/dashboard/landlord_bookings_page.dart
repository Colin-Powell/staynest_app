import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

import 'landlord_booking_detail_page.dart';
import 'landlord_calendar_page.dart';

class LandlordBookingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const LandlordBookingsPage({super.key, this.onBack});

  @override
  State<LandlordBookingsPage> createState() => _LandlordBookingsPageState();
}

class _LandlordBookingsPageState extends State<LandlordBookingsPage> {
  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Completed', 'Cancelled'];

  // Design Tokens - Landlord Emerald Theme
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textMedium = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF9CA3AF);

  // Status Pill Colors mapped to the Theme
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF065F46), // Deep Green Text
    },
    'Completed': {
      'bg': Color(0xFFE0E7FF), // Soft Indigo/Blue BG
      'text': Color(0xFF3730A3), // Deep Indigo Text
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
          
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header (No back button)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'My Bookings',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
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

                    // Filter Tabs
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 44,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadBookings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
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
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildBookingSkeletonCard(),
                              );
                            },
                            childCount: 4,
                          ),
                        ),
                      )
                    else if (_filteredBookings.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GlassContainer(
                                padding: const EdgeInsets.all(24),
                                child: Icon(PhosphorIcons.calendarBlank(), size: 48, color: textLight),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No $_selectedTab bookings',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bookings will appear here when you receive reservations.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
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
                          MediaQuery.of(context).padding.bottom + 200, // Extra padding so cards don't hide behind floating button
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final booking = _filteredBookings[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LandlordBookingDetailPage(
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

                // Floating "View Calendar" Glass Button
                // Pushed higher up to prevent overlapping with the AppShell bottom navigation bar
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 120, // Increased bottom padding
                      left: 32,
                      right: 32,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(LandlordCalendarPage.route()),
                              child: Center(
                                child: Text(
                                  'View Calendar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
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

    return GestureDetector(
      onTap: () {
        if (_selectedTab == label) return;
        setState(() {
          _selectedTab = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryGreen.withOpacity(0.15) : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? primaryGreen : Colors.white.withOpacity(0.8),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              color: isActive ? primaryGreen : textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'Upcoming';
    final statusColor = statusColors[status]!['text']!;
    final statusBg = statusColors[status]!['bg']!;

    return _GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 145,
        child: Row(
          children: [
            // Flush Image on the left
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                bottomLeft: Radius.circular(24),
              ),
              child: buildPropertyImage(
                booking['image'] ?? '',
                width: 120,
                height: double.infinity,
                fit: BoxFit.cover,
                errorPlaceholder: Container(
                  width: 120,
                  height: double.infinity,
                  color: const Color(0xFFE8F6EF),
                  child: Icon(PhosphorIcons.house(), color: primaryGreen.withOpacity(0.5), size: 32),
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
                    // Title and Icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            booking['title'] ?? 'Booking',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    
                    // Location & Tenant Name
                    Text(
                      '${booking['location']} • ${booking['tenant_name']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textLight,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Price
                    Text(
                      'Kes. ${booking['price']}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Date & Status Pill
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${booking['date']} | ${booking['time']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textMedium,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
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
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 145,
        child: Row(
          children: [
            Container(
              width: 120,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 120,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 100,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(10),
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
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
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