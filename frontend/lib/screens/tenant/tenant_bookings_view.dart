import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Tenant Design System Constants ───────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _tenantPrimary = Color(0xFF3F37C9); // Tenant Blue Theme

class TenantBookingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const TenantBookingsView({super.key, this.onBack});

  @override
  State<TenantBookingsView> createState() => _TenantBookingsViewState();
}

class _TenantBookingsViewState extends State<TenantBookingsView> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  bool _hasError = false;

  String _selectedStatus = 'All';

  static const List<String> _statusFilters = [
    'All',
    'pending',
    'confirmed',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final data = await BookingService.fetchBookings(isLandlord: false);
      if (mounted) {
        setState(() {
          _bookings = data.map((b) => b as Map<String, dynamic>).toList();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedStatus == 'All') return _bookings;
    return _bookings
        .where((b) => b['status'].toString().toLowerCase() == _selectedStatus.toLowerCase())
        .toList();
  }

  void _switchStatus(String status) {
    setState(() => _selectedStatus = status);
  }

  Future<void> _cancelBooking(String bookingId) async {
    final reason = await _showCancelDialog();
    if (reason == null) return;

    // Optimistic loading feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: _tenantPrimary)),
    );

    try {
      await BookingService.updateStatus(bookingId, 'cancel', reason: reason);
      if (mounted) Navigator.pop(context); // Pop loading
      await _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel booking.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<String?> _showCancelDialog() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: Text('Cancel Booking', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _dark, letterSpacing: -0.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel this booking? You can optionally provide a reason below.', style: GoogleFonts.poppins(color: _grey, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: GoogleFonts.poppins(fontSize: 14, color: _dark),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for cancellation (optional)',
                hintStyle: GoogleFonts.poppins(color: _grey, fontSize: 14),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _tenantPrimary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Booking', style: GoogleFonts.poppins(color: _dark, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF2F2),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Cancel Booking', style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── UI BUILDERS ─────────────────────────────────────────────────────────────

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final status = _statusFilters[index];
          final isActive = status == _selectedStatus;
          final label = status == 'All' ? 'All Bookings' : '${status[0].toUpperCase()}${status.substring(1)}';

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _switchStatus(status),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
                  child: Container(width: 130, decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.horizontal(left: Radius.circular(24)))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100, child: Container(width: double.infinity, height: 16, color: Colors.white)),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100, child: Container(width: 100, height: 12, color: Colors.white)),
                        const Spacer(),
                        Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100, child: Container(width: double.infinity, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.warningCircle, size: 48, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 24),
            Text('Failed to load bookings', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text('We encountered an issue fetching your data.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadBookings,
              style: ElevatedButton.styleFrom(backgroundColor: _tenantPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)), padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: Text('Retry', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedStatus != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: _grey.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(PhosphorIconsRegular.calendarSlash, size: 48, color: _grey),
            ),
            const SizedBox(height: 24),
            Text(isFiltered ? 'No ${_selectedStatus.toLowerCase()} bookings' : 'No bookings yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: _dark)),
            const SizedBox(height: 8),
            Text('Your reservations will appear here once you book a property.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850), // Responsive desktop constraint
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Header ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onBack ?? () => Navigator.pop(context),
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

                // ─── Filter Tabs ───
                _buildFilterTabs(),
                const SizedBox(height: 24),

                // ─── Content ───
                Expanded(
                  child: _loading
                      ? _buildShimmerLoading()
                      : _hasError
                          ? _buildErrorState()
                          : _filteredBookings.isEmpty
                              ? _buildEmptyState()
                              : RefreshIndicator(
                                  color: _tenantPrimary,
                                  backgroundColor: _surface,
                                  onRefresh: _loadBookings,
                                  child: ListView.builder(
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    padding: EdgeInsets.only(left: 24, right: 24, bottom: MediaQuery.of(context).padding.bottom + 40),
                                    itemCount: _filteredBookings.length,
                                    itemBuilder: (context, index) {
                                      final booking = _filteredBookings[index];
                                      return _BookingCard(
                                        booking: booking,
                                        onCancel: () => _cancelBooking(booking['id'].toString()),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Beautiful Booking Card ───────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onCancel;

  const _BookingCard({required this.booking, this.onCancel});

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFF59E0B); // Amber
      case 'confirmed': return _tenantPrimary; // Blue
      case 'completed': return const Color(0xFF10B981); // Emerald
      case 'cancelled': return const Color(0xFFEF4444); // Red
      case 'rejected': return const Color(0xFFEF4444); // Red
      default: return _grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (booking['status'] ?? 'pending').toString().toLowerCase();
    final uiStatus = status == 'pending' ? 'Pending' : status == 'confirmed' ? 'Confirmed' : status == 'completed' ? 'Completed' : 'Cancelled';
    final statusColor = _getStatusColor(status);
    
    final checkInDate = booking['check_in_date']?.toString() ?? '';
    final checkOutDate = booking['check_out_date']?.toString() ?? '';
    final totalPrice = booking['total_price']?.toString() ?? '0';

    // Safely extract property details from nested relation if it exists
    final propertyPayload = booking['property'] is Map ? booking['property'] : booking;
    final propertyTitle = propertyPayload['title']?.toString() ?? propertyPayload['name']?.toString() ?? 'Property';
    final propertyLocation = propertyPayload['city']?.toString() ?? propertyPayload['location']?.toString() ?? '';
    
    // Extract Image
    final propertyImages = propertyPayload['images'] is List ? List<String>.from(propertyPayload['images']) : <String>[];
    final imageUrl = propertyImages.isNotEmpty ? propertyImages.first : (propertyPayload['image_url'] ?? propertyPayload['image'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _grey.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top: Image & Status ───
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: buildPropertyImage(
                    imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorPlaceholder: Container(width: 100, height: 100, color: _grey.withOpacity(0.1), child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              propertyTitle,
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _dark),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(uiStatus, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(PhosphorIconsRegular.mapPin, size: 12, color: _grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(propertyLocation, style: GoogleFonts.poppins(fontSize: 13, color: _grey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        checkOutDate.isNotEmpty ? '${_formatDate(checkInDate)} - ${_formatDate(checkOutDate)}' : _formatDate(checkInDate),
                        style: GoogleFonts.poppins(fontSize: 13, color: _dark, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ksh. $totalPrice',
                        style: GoogleFonts.poppins(fontSize: 14, color: _tenantPrimary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Bottom: Actions ───
          if (status == 'completed' || status == 'pending' || status == 'confirmed')
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: _grey.withOpacity(0.1)))),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (status == 'completed')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Placeholder for receipt functionality
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating receipt...')));
                        },
                        icon: const Icon(PhosphorIconsRegular.receipt, size: 18),
                        label: Text('View Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _dark,
                          side: BorderSide(color: _grey.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel Booking', style: GoogleFonts.poppins(color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
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