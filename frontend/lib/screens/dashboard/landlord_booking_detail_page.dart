import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/booking_service.dart';
import 'package:property_app/services/booking_action_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/widgets/property_image.dart';

class LandlordBookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> booking;

  const LandlordBookingDetailPage({super.key, required this.booking});

  @override
  State<LandlordBookingDetailPage> createState() =>
      _LandlordBookingDetailPageState();
}

class _LandlordBookingDetailPageState extends State<LandlordBookingDetailPage> {
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);

  // Standardized Status Colors
  static const Map<String, Color> statusColors = {
    'pending': Color(0xFFFB923C),
    'confirmed': Color(0xFF059669),
    'accepted': Color(0xFF059669),
    'cancelled': Color(0xFFEF4444),
    'rejected': Color(0xFFEF4444),
    'completed': Color(0xFF3F37C9),
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
    return statusColors[status.toLowerCase()] ?? textLight;
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final status = booking['status']?.toString() ?? 'Upcoming';
    // Support both API structures securely
    final isPending = booking['rawStatus'] == 'pending' ||
        booking['status'].toString().toLowerCase() == 'pending';

    final statusColor = _getStatusColor(status);

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
            child: Column(
              children: [
                // 2. Custom Minimal Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: textDark, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Request Details',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Main Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Tenant Card ---
                        _GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              ClipOval(
                                child: AppSession.buildAvatar(
                                  booking['tenant_avatar']?.toString(),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
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
                                        color: textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Requested a visit',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/chat',
                                      arguments: <String, String>{
                                        'userId':
                                            booking['tenant_id']?.toString() ??
                                                '',
                                        'name': booking['tenant_name']
                                                ?.toString() ??
                                            'Tenant',
                                        'avatar': booking['tenant_avatar']
                                                ?.toString() ??
                                            '',
                                      });
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: primaryGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      PhosphorIcons.chatTeardropText(
                                          PhosphorIconsStyle.fill),
                                      color: primaryGreen,
                                      size: 22),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // --- Property & Visit Details Card (Netflix Theme) ---
                        _GlassContainer(
                          padding: EdgeInsets
                              .zero, // Make image flush to the container bounds
                          child: SizedBox(
                            height: 320, // Tall cinematic card
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background Image
                                buildPropertyImage(
                                  booking['image'] ?? '',
                                  fit: BoxFit.cover,
                                  errorPlaceholder:
                                      Container(color: const Color(0xFFE8F6EF)),
                                ),
                                // Dark Gradient Overlay at the bottom
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.2),
                                        Colors.black.withOpacity(0.95),
                                      ],
                                      stops: const [0.3, 0.6, 1.0],
                                    ),
                                  ),
                                ),
                                // Overlay Content aligned to the bottom
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          booking['title'] ?? 'Property Name',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                                PhosphorIcons.mapPin(
                                                    PhosphorIconsStyle.fill),
                                                size: 16,
                                                color: Colors.white70),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                booking['location'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                    color: Colors.white70,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Divider(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            height: 1,
                                            thickness: 1),
                                        const SizedBox(height: 20),
                                        // Quick Info Grid
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildInfoColumn(
                                                  PhosphorIcons.calendarBlank(),
                                                  'Date',
                                                  booking['date'] ?? 'TBD',
                                                  isLight: true),
                                            ),
                                            Container(
                                                width: 1,
                                                height: 40,
                                                color: Colors.white
                                                    .withOpacity(0.2)),
                                            Expanded(
                                              child: _buildInfoColumn(
                                                  PhosphorIcons.clock(),
                                                  'Time',
                                                  booking['time'] ?? '10:00 AM',
                                                  isLight: true),
                                            ),
                                            Container(
                                                width: 1,
                                                height: 40,
                                                color: Colors.white
                                                    .withOpacity(0.2)),
                                            Expanded(
                                              child: _buildInfoColumn(
                                                  PhosphorIcons.wallet(),
                                                  'Price',
                                                  'Kes. ${booking['price'] ?? 0}',
                                                  isLight: true),
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
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Floating Action Bar Pinned to Bottom
          if (!isPending && status != 'Upcoming')
            const SizedBox.shrink()
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                        24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.6),
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.5)),
                    ),
                    child: _isProcessing
                        ? const Center(
                            heightFactor: 1,
                            child:
                                CircularProgressIndicator(color: primaryGreen),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPending) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () =>
                                            _handleAction('Rejected'),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                        ),
                                        child: Text(
                                          'Decline',
                                          style: GoogleFonts.poppins(
                                              color: const Color(0xFFEF4444),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _handleAction('Accepted'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryGreen,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                        ),
                                        child: Text(
                                          'Accept',
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (status == 'Upcoming' || isPending) ...[
                                if (isPending) const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now()
                                                .add(const Duration(days: 365)),
                                            builder: (context, child) {
                                              return Theme(
                                                data:
                                                    Theme.of(context).copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                    primary: primaryGreen,
                                                    onPrimary: Colors.white,
                                                    onSurface: textDark,
                                                  ),
                                                ),
                                                child: child!,
                                              );
                                            });
                                    if (picked != null && mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Rescheduling request sent for ${picked.toLocal().toString().split(' ')[0]}',
                                              style: GoogleFonts.poppins()),
                                          backgroundColor: primaryGreen,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? Colors.transparent
                                          : primaryGreen,
                                      border: Border.all(
                                          color: primaryGreen, width: 1.5),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(PhosphorIcons.calendarPlus(),
                                            color: isPending
                                                ? primaryGreen
                                                : Colors.white,
                                            size: 20),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Reschedule Visit',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isPending
                                                ? primaryGreen
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildInfoColumn(IconData icon, String label, String value,
      {bool isLight = false}) {
    return Column(
      children: [
        Icon(icon, size: 22, color: isLight ? Colors.white : primaryGreen),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isLight ? Colors.white : textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isLight ? Colors.white70 : textLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  const _GlassContainer({required this.child, this.padding = EdgeInsets.zero, this.borderRadius, this.blur = 16.0, this.opacity = 0.1, this.borderWidth = 1.0});


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
