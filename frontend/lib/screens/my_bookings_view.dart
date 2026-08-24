// lib/screens/my_bookings_view.dart
import 'package:flutter/material.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/data_loader/fallback_properties_loader.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

/// A wrapper to attach booking-specific mock data (Date & Status) to standard properties
class BookingWrapper {
  final Property property;
  final String dateTime;
  final String status;
  final String bookingId;
  final Map<String, dynamic> rawData;

  BookingWrapper({
    required this.property,
    required this.dateTime,
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
  String _activeTab = 'Upcoming';

  final _loader = FallbackPropertiesLoader(
    remoteRepository: RemoteDatabaseRepository(),
  );
  List<BookingWrapper> _allBookings = [];
  bool _loading = true;
  bool _hasError = false;

  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    try {
      final bookings = await BookingService.fetchBookings(isLandlord: false);
      if (!mounted) return;

      setState(() {
        _allBookings = bookings.map((b) {
          String uiStatus = 'Upcoming';
          if (b['status'] == 'confirmed' || b['status'] == 'pending') {
            uiStatus = 'Upcoming';
          }
          if (b['status'] == 'completed') uiStatus = 'Completed';
          if (b['status'] == 'cancelled' || b['status'] == 'rejected') {
            uiStatus = 'Cancelled';
          }

          final checkIn = DateTime.parse(b['check_in_date']);
          final dateStr = "${checkIn.day}/${checkIn.month}/${checkIn.year}";

          return BookingWrapper(
            property: Property(
              id: b['property_id']?.toString() ?? '',
              name: b['property_name'] ?? 'Unknown Property',
              location: 'See Details',
              image: b['property_image'] ?? '',
              price: int.tryParse(b['total_price']?.toString() ?? '') ?? 0,
              lat: 0, lng: 0,
              rating: 0.0,
              reviews: 0,
              category: '', images: [],
              features: const PropertyFeatures(beds: 0, rooms: 0, baths: 0, furnished: false),
              amenities: [], agent: const Agent(userId: '', name: '', avatar: ''),
              description: '',
            ),
            dateTime: dateStr,
            status: uiStatus,
            bookingId: b['id']?.toString() ?? '',
            rawData: Map<String, dynamic>.from(b),
          );
        }).toList();
        _loading = false;
      });

      _animController.forward(from: 0.0);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  void _switchTab(String tab) {
    if (tab == _activeTab) return;
    setState(() => _activeTab = tab);
    // Restart cascade animation for newly filtered items
    _animController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Staggered cascade animation helper
  Widget _buildStaggered({required Widget child, required int index}) {
    final double start = (index * 0.1).clamp(0.0, 1.0);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter bookings by active tab
    final displayBookings =
        _allBookings.where((b) => b.status == _activeTab).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onBack: widget.onBack),
            _TabBar(
              tabs: _tabs,
              active: _activeTab,
              onTap: _switchTab,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4F46E5),
                      ),
                    )
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Failed to load bookings.',
                                  style: TextStyle(color: Colors.red)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                  : ScrollConfiguration(
                      behavior: const AppScrollBehavior(),
                      child: displayBookings.isEmpty
                          ? Center(
                              child: Text(
                                'No $_activeTab Bookings',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(
                                decelerationRate: ScrollDecelerationRate.fast,
                              ),
                              padding: EdgeInsets.fromLTRB(
                                20,
                                16,
                                20,
                                MediaQuery.of(context).padding.bottom + 40,
                              ),
                              itemCount: displayBookings.length,
                              itemBuilder: (context, i) {
                                return _buildStaggered(
                                  index: i,
                                  child: GestureDetector(
                                    onTap: () => _showBookingDetail(displayBookings[i]),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 20),
                                      child: _BookingCard(booking: displayBookings[i]),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBookingDetail(BookingWrapper b) async {
    final raw = b.rawData;
    final checkIn = raw['check_in_date']?.toString() ?? '';
    final checkOut = raw['check_out_date']?.toString() ?? '';
    final total = raw['total_price']?.toString() ?? '—';
    final nights = raw['nights']?.toString() ?? '—';
    final backendStatus = raw['status']?.toString() ?? b.status;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(b.property.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('Booking #${b.bookingId.length > 8 ? b.bookingId.substring(0, 8).toUpperCase() : b.bookingId}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 20),
            _DetailRow(label: 'Check-in', value: checkIn),
            _DetailRow(label: 'Check-out', value: checkOut),
            if (nights != '—') _DetailRow(label: 'Duration', value: '$nights night(s)'),
            _DetailRow(label: 'Total', value: 'Ksh $total'),
            _DetailRow(label: 'Status', value: backendStatus.toUpperCase()),
            if (b.status == 'Upcoming') ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _cancelBooking(b);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancel Booking',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelBooking(BookingWrapper b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to cancel your booking for ${b.property.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Booking', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await BookingService.updateStatus(b.bookingId, 'cancel');
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled'), behavior: SnackBarBehavior.floating),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel booking. Please try again.'),
            behavior: SnackBarBehavior.floating),
      );
    }
  }
}


// ==================== SHARED WIDGETS ====================

// Header
class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(right: 16, top: 4, bottom: 4),
              child: Icon(
                Icons.arrow_back,
                size: 28,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tab Bar matching PDF perfectly
class _TabBar extends StatelessWidget {
  final List<String> tabs;
  final String active;
  final void Function(String) onTap;

  const _TabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
            final isActive = tab == active;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(


              onTap: () => onTap(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                  border: isActive
                      ? Border.all(color: Colors.transparent)
                      : Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      )
    );
  }
}

// Booking Card mapped to real Property data
class _BookingCard extends StatelessWidget {
  final BookingWrapper booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBgColor;

    if (booking.status == 'Completed') {
      statusColor = const Color(0xFF10B981);
      statusBgColor = const Color(0xFFD1FAE5);
    } else if (booking.status == 'Cancelled') {
      statusColor = const Color(0xFFF43F5E);
      statusBgColor = const Color(0xFFFFE4E6);
    } else {
      statusColor = const Color(0xFF4F46E5);
      statusBgColor = const Color(0xFFEEF2FF);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  child: buildPropertyImage(
                    booking.property.image,
                    width: 120,
                    // Providing a fallback finite height prevents infinite BoxConstraints exception.
                    // The 'stretch' aligns the height to match the text column dynamically.
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Visually center the text layout vertically
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                booking.property.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (booking.property.reviews > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 4),
                              Text(
                                booking.property.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          booking.property.location,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF9CA3AF),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          booking.dateTime,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              booking.status,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
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
          const Positioned(
            top: 16,
            right: 16,
            child: Icon(
              Icons.favorite_rounded,
              color: Color(0xFFEC4899), // Pink Heart matching PDF
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Smooth Scroll Behavior
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.fast);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: Color(0xFF111827), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
