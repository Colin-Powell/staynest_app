import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/booking_action_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';

// ─── Landlord Design System Constants ─────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;
const Color _green = Color(0xFF10B981); // Emerald Green for Landlord Theme

class LandlordBookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const LandlordBookingDetailPage({super.key, required this.booking});

  @override
  State<LandlordBookingDetailPage> createState() =>
      _LandlordBookingDetailPageState();
}

class _LandlordBookingDetailPageState extends State<LandlordBookingDetailPage> {
  // Standardized Status Colors
  static const Map<String, Color> statusColors = {
    'pending': Color(0xFFF59E0B), // Amber
    'confirmed': Color(0xFF10B981), // Emerald
    'accepted': Color(0xFF10B981),
    'cancelled': Color(0xFFEF4444), // Red
    'rejected': Color(0xFFEF4444),
    'completed': Color(0xFF3B82F6), // Blue
  };

  bool _isProcessing = false;

  Future<void> _handleAction(String action) async {
    setState(() => _isProcessing = true);

    final success = await BookingActionService.performAction(
      context: context,
      bookingId: widget.booking['id'].toString(),
      action: action,
    );

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _isProcessing = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    return statusColors[status.toLowerCase()] ?? _grey;
  }
  
  String _formatDateString(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'TBD') return 'TBD';
    try {
      final date = DateTime.parse(dateStr.split('T')[0]);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking['status']?.toString() ?? 'Upcoming';
    
    final isPending = booking['rawStatus'] == 'pending' || 
                      booking['status'].toString().toLowerCase() == 'pending';
    
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(PhosphorIconsRegular.caretLeft, color: _dark, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Request Details',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Main Scrollable Content ───
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Tenant Card ---
                    Container(
                      padding: const EdgeInsets.all(16),
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
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _grey.withOpacity(0.2)),
                            ),
                            child: ClipOval(
                              child: AppSession.buildAvatar(
                                booking['tenant_avatar']?.toString(),
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking['tenant_name'] ?? 'Prospective Tenant',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Requested a visit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/chat',
                                  arguments: <String, String>{
                                    'userId': booking['tenant_id']?.toString() ?? '',
                                    'name': booking['tenant_name']?.toString() ?? 'Tenant',
                                    'avatar': booking['tenant_avatar']?.toString() ?? '',
                                  });
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsFill.chatTeardropText,
                                color: _green,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- Property & Visit Details Card ---
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Image
                          SizedBox(
                            height: 220, // Taller for a premium look
                            width: double.infinity, // Forces full width
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                              child: Stack(
                                fit: StackFit.expand, // Forces child to fill container
                                children: [
                                  buildPropertyImage(
                                    booking['image'] ?? '',
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorPlaceholder: Container(
                                      color: _grey.withOpacity(0.1),
                                      child: const Icon(PhosphorIconsRegular.house, color: _grey, size: 48),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Bottom Details
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking['title'] ?? 'Property Name',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(PhosphorIconsRegular.mapPin, size: 16, color: _grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        booking['location'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: _grey,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Divider(color: _grey.withOpacity(0.2), height: 1),
                                const SizedBox(height: 20),
                                
                                // Quick Info Grid
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _buildInfoColumn(
                                        PhosphorIconsRegular.calendarBlank,
                                        'Date',
                                        _formatDateString(booking['date'] ?? 'TBD'),
                                      ),
                                    ),
                                    Container(width: 1, height: 40, color: _grey.withOpacity(0.2)),
                                    Expanded(
                                      child: _buildInfoColumn(
                                        PhosphorIconsRegular.clock,
                                        'Time',
                                        booking['time'] ?? '10:00 AM',
                                      ),
                                    ),
                                    Container(width: 1, height: 40, color: _grey.withOpacity(0.2)),
                                    Expanded(
                                      child: _buildInfoColumn(
                                        PhosphorIconsRegular.wallet,
                                        'Price',
                                        'Ksh. ${booking['price'] ?? 0}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Bottom Action Bar ───
            if (isPending || status == 'Upcoming')
              Container(
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: _surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border(top: BorderSide(color: _grey.withOpacity(0.1))),
                ),
                child: _isProcessing
                    ? const Center(
                        heightFactor: 1,
                        child: CircularProgressIndicator(color: _green),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPending) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => _handleAction('Rejected'),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: const Color(0xFFFEF2F2), // Soft Red
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                    ),
                                    child: Text(
                                      'Decline',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFEF4444),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleAction('Accepted'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _green,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                    ),
                                    child: Text(
                                      'Accept',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Reschedule Button
                          GestureDetector(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: _green,
                                        onPrimary: Colors.white,
                                        onSurface: _dark,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                }
                              );
                              if (picked != null && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Rescheduling request sent for ${_formatDateString(picked.toIso8601String())}',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: _green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isPending ? Colors.transparent : _green,
                                border: Border.all(color: _green, width: 1.5),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    PhosphorIconsRegular.calendarPlus,
                                    color: isPending ? _green : Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Reschedule Visit',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isPending ? _green : Colors.white,
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
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 22, color: _dark),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}