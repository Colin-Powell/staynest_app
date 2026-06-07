import 'package:flutter/material.dart';
import 'package:property_app/services/booking_service.dart';

class TenantBookingsView extends StatefulWidget {
  final VoidCallback? onBack;

  const TenantBookingsView({super.key, this.onBack});

  @override
  State<TenantBookingsView> createState() => _TenantBookingsViewState();
}

class _TenantBookingsViewState extends State<TenantBookingsView> {
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _filteredBookings = [];
  bool _loading = true;

  static const Color tenantPrimary = Color(0xFF3F37C9);

  String _selectedStatus = 'All';

  static const List<String> _statusFilters = [
    'All',
    'pending',
    'confirmed',
    'cancelled',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final data = await BookingService.fetchBookings(isLandlord: false);
      if (mounted) {
        setState(() {
          _bookings = data.map((b) => b as Map<String, dynamic>).toList();
          _filterBookings();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filterBookings() {
    if (_selectedStatus == 'All') {
      _filteredBookings = _bookings;
    } else {
      _filteredBookings =
          _bookings.where((b) => b['status'] == _selectedStatus).toList();
    }
  }

  void _switchStatus(String status) {
    setState(() {
      _selectedStatus = status;
      _filterBookings();
    });
  }

  Future<void> _cancelBooking(String bookingId) async {
    final reason = await _showCancelDialog();
    if (reason == null) return;

    try {
      await BookingService.updateStatus(bookingId, 'cancel', reason: reason);
      _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling booking: $e')),
        );
      }
    }
  }

  Future<String?> _showCancelDialog() async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Reason for cancellation (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abort'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Cancel Booking',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Color(0xFF374151)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'My Bookings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status filters
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _statusFilters.length,
                itemBuilder: (context, index) {
                  final status = _statusFilters[index];
                  final isActive = status == _selectedStatus;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () => _switchStatus(status),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? tenantPrimary
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                          border: isActive
                              ? null
                              : Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Bookings list
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: tenantPrimary),
                    )
                  : _filteredBookings.isEmpty
                      ? Center(
                          child: Text(
                            'No $_selectedStatus bookings',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
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
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    this.onCancel,
  });

  static const Color tenantPrimary = Color(0xFF3F37C9);

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFB923C);
      case 'confirmed':
        return tenantPrimary;
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'completed':
        return tenantPrimary;
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (booking['status'] ?? 'pending').toString().toUpperCase();
    final checkInDate = booking['check_in_date']?.toString() ?? '';
    final checkOutDate = booking['check_out_date']?.toString() ?? '';
    final landlordName =
        booking['landlord_name']?.toString() ?? 'Unknown Landlord';
    final propertyTitle = booking['title']?.toString() ?? 'Unknown Property';
    final totalPrice = booking['total_price']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property title and status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  propertyTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                          (booking['status'] ?? 'pending').toString())
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: _getStatusColor(
                        (booking['status'] ?? 'pending').toString()),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Landlord info
          Text(
            'Landlord: $landlordName',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // Dates
          Text(
            'Check-in: ${_formatDate(checkInDate)} | Check-out: ${_formatDate(checkOutDate)}',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // Price
          Text(
            'Total: KES $totalPrice',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          if ((booking['status'] ?? 'pending').toString().toLowerCase() ==
              'completed')
            GestureDetector(
              onTap: () {
                // Placeholder for receipt functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating receipt...')),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: tenantPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tenantPrimary),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          color: tenantPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'View Receipt',
                        style: TextStyle(
                          color: tenantPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if ((booking['status'] ?? '').toString().toLowerCase() !=
              'cancelled')
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: const Center(
                  child: Text(
                    'Cancel Booking',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
