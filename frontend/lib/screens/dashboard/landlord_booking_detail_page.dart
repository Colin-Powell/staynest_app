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
  final ValueChanged<bool>? onClose;

  const LandlordBookingDetailPage({
    super.key,
    required this.booking,
    this.onClose,
  });

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

  void _close({bool changed = false}) {
    if (widget.onClose != null) {
      widget.onClose!(changed);
      return;
    }
    Navigator.pop(context, changed);
  }

  Future<void> _handleAction(String action) async {
    setState(() => _isProcessing = true);

    final success = await BookingActionService.performAction(
      context: context,
      bookingId: widget.booking['id'].toString(),
      action: action,
    );

    if (mounted) {
      if (success) {
        _close(changed: true);
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

  void _openChat(Map<String, dynamic> booking) {
    Navigator.pushNamed(context, '/chat', arguments: <String, String>{
      'userId': booking['tenant_id']?.toString() ?? '',
      'name': booking['tenant_name']?.toString() ?? 'Tenant',
      'avatar': booking['tenant_avatar']?.toString() ?? '',
    });
  }

  Future<void> _handleReschedule() async {
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
        });
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
  }

  // ─── UI BUILDERS ────────────────────────────────────────────────────────────

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

  // ─── DESKTOP LAYOUT ─────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(
    Map<String, dynamic> booking,
    String status,
    bool isPending,
    bool canMarkCompleted,
    Color statusColor,
  ) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: IconButton(
            icon: const Icon(PhosphorIconsRegular.caretLeft,
                color: _dark, size: 24),
            onPressed: _close,
          ),
        ),
        title: Text(
          'Request Details',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _dark,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANE: Property & Visit Details
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Massive Premium Image
                        SizedBox(
                          height: 380,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                            child: buildPropertyImage(
                              booking['image'] ?? '',
                              fit: BoxFit.cover,
                              errorPlaceholder: Container(
                                color: _grey.withOpacity(0.1),
                                child: const Icon(PhosphorIconsRegular.house,
                                    color: _grey, size: 48),
                              ),
                            ),
                          ),
                        ),
                        // Bottom Details
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking['title'] ?? 'Property Name',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(PhosphorIconsRegular.mapPin,
                                      size: 18, color: _grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      booking['location'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: _grey,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Divider(color: _grey.withOpacity(0.2), height: 1),
                              const SizedBox(height: 32),

                              // Quick Info Grid
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: _buildInfoColumn(
                                      PhosphorIconsRegular.calendarBlank,
                                      'Date',
                                      _formatDateString(
                                          booking['date'] ?? 'TBD'),
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 50,
                                      color: _grey.withOpacity(0.2)),
                                  Expanded(
                                    child: _buildInfoColumn(
                                      PhosphorIconsRegular.clock,
                                      'Time',
                                      booking['time'] ?? '10:00 AM',
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 50,
                                      color: _grey.withOpacity(0.2)),
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
                ),

                const SizedBox(width: 32), // Gutter

                // RIGHT PANE: Tenant & Actions
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      // Tenant Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _grey.withOpacity(0.2)),
                              ),
                              child: ClipOval(
                                child: AppSession.buildAvatar(
                                  booking['tenant_avatar']?.toString(),
                                  width: 56,
                                  height: 56,
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
                                    booking['tenant_name'] ??
                                        'Prospective Tenant',
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
                            IconButton(
                              onPressed: () => _openChat(booking),
                              icon: const Icon(
                                  PhosphorIconsFill.chatTeardropText,
                                  color: _green,
                                  size: 24),
                              style: IconButton.styleFrom(
                                backgroundColor: _green.withOpacity(0.1),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Actions Card
                      if (isPending || status == 'Upcoming' || canMarkCompleted)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _isProcessing
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: CircularProgressIndicator(
                                        color: _green),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (isPending) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () =>
                                                  _handleAction('Rejected'),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                backgroundColor:
                                                    const Color(0xFFFEF2F2),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            32)),
                                              ),
                                              child: Text(
                                                'Decline',
                                                style: GoogleFonts.poppins(
                                                  color:
                                                      const Color(0xFFEF4444),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _handleAction('Accepted'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _green,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            32)),
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
                                      const SizedBox(height: 16),
                                    ],
                                    if (canMarkCompleted) ...[
                                      FilledButton.icon(
                                        onPressed: () =>
                                            _handleAction('Completed'),
                                        icon:
                                            const Icon(Icons.task_alt_rounded),
                                        label: Text('Mark stay completed',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            )),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _green,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(32)),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    OutlinedButton.icon(
                                      onPressed: _handleReschedule,
                                      icon: Icon(
                                        PhosphorIconsRegular.calendarPlus,
                                        color: isPending ? _green : _dark,
                                        size: 20,
                                      ),
                                      label: Text(
                                        'Reschedule Visit',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isPending ? _green : _dark,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        side: BorderSide(
                                            color: isPending
                                                ? _green
                                                : _grey.withOpacity(0.3),
                                            width: 1.5),
                                        backgroundColor: isPending
                                            ? _green.withOpacity(0.05)
                                            : Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(32)),
                                      ),
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
      ),
    );
  }

  // ─── MOBILE LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    Map<String, dynamic> booking,
    String status,
    bool isPending,
    bool canMarkCompleted,
    Color statusColor,
  ) {
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
                    onTap: _close,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(PhosphorIconsRegular.caretLeft,
                        color: _dark, size: 24),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                  booking['tenant_name'] ??
                                      'Prospective Tenant',
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
                            onTap: () => _openChat(booking),
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
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24)),
                              child: Stack(
                                fit: StackFit
                                    .expand, // Forces child to fill container
                                children: [
                                  buildPropertyImage(
                                    booking['image'] ?? '',
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorPlaceholder: Container(
                                      color: _grey.withOpacity(0.1),
                                      child: const Icon(
                                          PhosphorIconsRegular.house,
                                          color: _grey,
                                          size: 48),
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
                                    const Icon(PhosphorIconsRegular.mapPin,
                                        size: 16, color: _grey),
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
                                Divider(
                                    color: _grey.withOpacity(0.2), height: 1),
                                const SizedBox(height: 20),

                                // Quick Info Grid
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _buildInfoColumn(
                                        PhosphorIconsRegular.calendarBlank,
                                        'Date',
                                        _formatDateString(
                                            booking['date'] ?? 'TBD'),
                                      ),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: _grey.withOpacity(0.2)),
                                    Expanded(
                                      child: _buildInfoColumn(
                                        PhosphorIconsRegular.clock,
                                        'Time',
                                        booking['time'] ?? '10:00 AM',
                                      ),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 40,
                                        color: _grey.withOpacity(0.2)),
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
            if (isPending || status == 'Upcoming' || canMarkCompleted)
              Container(
                padding: EdgeInsets.fromLTRB(
                    24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: _surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border:
                      Border(top: BorderSide(color: _grey.withOpacity(0.1))),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      backgroundColor:
                                          const Color(0xFFFEF2F2), // Soft Red
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(32)),
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
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(32)),
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

                          if (canMarkCompleted) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _handleAction('Completed'),
                                icon: const Icon(Icons.task_alt_rounded),
                                label: const Text('Mark stay completed'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Reschedule Button
                          GestureDetector(
                            onTap: _handleReschedule,
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

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking['status']?.toString() ?? 'Upcoming';

    final isPending = booking['rawStatus'] == 'pending' ||
        booking['status'].toString().toLowerCase() == 'pending';
    final checkOutDate = DateTime.tryParse(
      booking['checkOutDate']?.toString() ?? '',
    );
    final canMarkCompleted = booking['rawStatus'] == 'confirmed' &&
        checkOutDate != null &&
        !DateUtils.dateOnly(checkOutDate)
            .isAfter(DateUtils.dateOnly(DateTime.now()));

    final statusColor = _getStatusColor(status);

    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    if (isDesktop) {
      return _buildDesktopLayout(
          booking, status, isPending, canMarkCompleted, statusColor);
    }

    return _buildMobileLayout(
        booking, status, isPending, canMarkCompleted, statusColor);
  }
}
