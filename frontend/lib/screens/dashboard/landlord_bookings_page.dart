import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/widgets/onboarding_bottom_sheet.dart';
import 'package:property_app/session/onboarding_prefs.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/utils/api_result.dart';

import 'landlord_booking_detail_page.dart';
import 'landlord_calendar_page.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green

class LandlordBookingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const LandlordBookingsPage({super.key, this.onBack});

  @override
  State<LandlordBookingsPage> createState() => _LandlordBookingsPageState();
}

class _LandlordBookingsPageState extends State<LandlordBookingsPage> {
  String _selectedTab = 'Upcoming';
  final List<String> _tabs = ['Upcoming', 'Completed', 'Cancelled'];

  // Status Pill Colors mapped to the minimal Theme
  static const Map<String, Map<String, Color>> statusColors = {
    'Upcoming': {
      'bg': Color(0xFFD1FAE5), // Soft Green BG
      'text': Color(0xFF065F46), // Deep Green Text
    },
    'Completed': {
      'bg': Color(0xFFEFF6FF), // Soft Blue BG
      'text': Color(0xFF1E40AF), // Deep Blue Text
    },
    'Cancelled': {
      'bg': Color(0xFFFEF2F2), // Soft Red BG
      'text': Color(0xFF991B1B), // Deep Red Text
    },
  };

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allBookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!OnboardingPrefs.hasSeen('landlordBookingsSeen')) {
        OnboardingBottomSheet.show(
          context: context,
          imagePath: 'assets/images/home_onboarding.png',
          title: 'Booking Requests',
          subtitle: 'Review tenant applications, approve bookings, and manage your reservation calendar.',
          ctaText: 'View Bookings',
        ).then((_) => OnboardingPrefs.markAsSeen('landlordBookingsSeen'));
      }
    });
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiResult.run(
      () => BookingService.fetchBookings(isLandlord: true),
    );

    if (!mounted) return;

    setState(() {
      if (result.isSuccess) {
        _allBookings = result.data!.map((b) {
          return {
            'id': b['id']?.toString() ?? '',
            'title': b['title']?.toString() ?? b['property_title']?.toString() ?? 'Property',
            'location': b['city']?.toString() ?? '',
            'tenant_id': b['tenant_id']?.toString() ?? '',
            'tenant_name': b['tenant_name']?.toString() ?? 'Tenant',
            'date': _formatDateString(b['check_in_date']?.toString() ?? ''),
            'time': '10:00 AM',
            'rawStatus': b['status']?.toString().toLowerCase() ?? '',
            'status': _mapStatus(b['status']?.toString() ?? ''),
            'image': b['image_url']?.toString() ?? '',
            'price': (double.tryParse(b['total_price']?.toString() ?? '0') ?? 0).toInt(),
            'rating': (double.tryParse(b['average_rating']?.toString() ?? '0') ?? 0.0).toDouble(),
            'reviews': int.tryParse(b['review_count']?.toString() ?? '0') ?? 0,
          };
        }).toList();
      } else {
        _errorMessage = result.error;
      }
      _isLoading = false;
    });
  }

  String _formatDateString(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr.split('T')[0];
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
          color: isActive ? _green : _surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive ? _green : _grey.withOpacity(0.2),
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
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 200),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                height: 120,
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
                        width: 120,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Shimmer.fromColors(
                                  baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                                  child: Container(width: 80, height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                                ),
                                Shimmer.fromColors(
                                  baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                                  child: Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
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
          },
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(PhosphorIconsRegular.calendarSlash, size: 64, color: _grey),
            const SizedBox(height: 20),
            Text(
              'No $_selectedTab bookings',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookings will appear here when you receive reservations.',
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'Upcoming';
    final statusColor = statusColors[status]?['text'] ?? const Color(0xFF065F46);
    final statusBg = statusColors[status]?['bg'] ?? const Color(0xFFD1FAE5);

    return Container(
      height: 124,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
              booking['image'] ?? '',
              width: 120,
              height: double.infinity,
              fit: BoxFit.cover,
              errorPlaceholder: Container(
                width: 120,
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
                  Text(
                    booking['title'] ?? 'Booking',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${booking['location']} • ${booking['tenant_name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if ((booking['reviews'] as int? ?? 0) > 0)
                    Row(
                      children: [
                        const Icon(PhosphorIconsFill.star, size: 12, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          (booking['rating'] as double? ?? 0.0).toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _dark,
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
                            'Ksh. ${booking['price']}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            booking['date'],
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _grey,
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
                          status,
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
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header (No back button)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Text(
                      'My Bookings',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                // Filter Tabs
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

                // Body
                if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(PhosphorIconsRegular.warningCircle, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: _dark,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: _loadBookings,
                            child: Text('Retry', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isLoading)
                  _buildShimmerLoading()
                else if (_filteredBookings.isEmpty)
                  _buildEmptyState()
                else
                  SliverPadding(
                    // Large bottom padding ensures cards scroll freely above the floating button
                    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 200),
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
                                  MaterialPageRoute(builder: (_) => LandlordBookingDetailPage(booking: booking)),
                                );
                                if (result == true) {
                                  _loadBookings();
                                }
                              },
                              behavior: HitTestBehavior.opaque,
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

            // Floating "View Calendar" Button restored to exact original clearance
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 120, // Clears the app's bottom navigation bar
              left: 24,
              right: 24,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(LandlordCalendarPage.route()),
                  icon: const Icon(PhosphorIconsRegular.calendarBlank, size: 20, color: Colors.white),
                  label: Text(
                    'View Calendar',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark, 
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
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