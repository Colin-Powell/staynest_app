import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/widgets/property_image.dart';

class LandlordBookingDetailPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const LandlordBookingDetailPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(booking['status'] as String? ?? '');
    final statusColor = _statusColor(booking['status'] as String? ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF7FCF8),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 28,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Booking Details',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: buildPropertyImage(
                        booking['image'] as String? ?? '',
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        errorPlaceholder: Container(
                          color: const Color(0xFFE5E7EB),
                          height: 220,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      booking['title'] as String? ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(),
                          color: const Color(0xFF6B7280),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          booking['location'] as String? ?? 'Unknown location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInfoCard(statusLabel, statusColor),
                    const SizedBox(height: 20),
                    _buildDetailRow(
                      PhosphorIcons.user(),
                      'Tenant',
                      booking['tenantName'] as String? ?? '',
                    ),
                    _buildDetailRow(
                      PhosphorIcons.calendarBlank(),
                      'Date',
                      booking['date'] as String? ?? '',
                    ),
                    _buildDetailRow(
                      PhosphorIcons.clock(),
                      'Time',
                      booking['time'] as String? ?? '',
                    ),
                    _buildDetailRow(
                      PhosphorIcons.buildings(),
                      'Request',
                      'Tenant requested a viewing visit',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Notes',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This booking request is part of the landlord schedule for the week. Confirm or reschedule directly from your calendar view.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String date) {
    return date;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Upcoming':
        return 'Upcoming';
      case 'Completed':
        return 'Completed';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return const Color(0xFF10B981);
      case 'Cancelled':
        return const Color(0xFFF43F5E);
      default:
        return const Color(0xFF3F37C9);
    }
  }

  Widget _buildInfoCard(String statusLabel, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking Status',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF6B7280), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
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
