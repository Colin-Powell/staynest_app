import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:property_app/services/booking_service.dart';

class BookingActionService {
  static const Color primaryGreen = Color(0xFF059669);
  static const Color textDark = Color(0xFF111827);
  static const Color textLight = Color(0xFF6B7280);

  /// Centralized handler for Accept/Reject actions
  static Future<bool> performAction({
    required BuildContext context,
    required String bookingId,
    required String action, // 'Accepted' or 'Rejected'
  }) async {
    String? reason;

    // 1. Show confirmation/reason dialog for rejections
    if (action == 'Rejected') {
      reason = await _showCancelDialog(context);
      if (reason == null) return false; // User cancelled the dialog
    }

    // 2. Execute API Call
    final apiAction = action == 'Accepted' ? 'confirm' : 'reject';
    final success = await BookingService.updateStatus(bookingId, apiAction);

    if (!context.mounted) return success;

    // 3. Provide standardized feedback
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking $action successfully', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update booking status', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return success;
  }

  static Future<String?> _showCancelDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String?>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Decline Request', 
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: textDark)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Reason for declining (optional)',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Go Back', 
                  style: GoogleFonts.poppins(color: textLight, fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Decline Now', 
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}