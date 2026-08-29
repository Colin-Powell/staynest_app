import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─── Alert Type ───────────────────────────────────────────────────────────────

enum AlertType { success, error, warning, info }

// ─── Alert Widget ─────────────────────────────────────────────────────────────

class AppAlert extends StatefulWidget {
  final AlertType type;
  final String message;
  final VoidCallback onClose;

  const AppAlert({
    super.key,
    required this.type,
    required this.message,
    required this.onClose,
  });

  @override
  State<AppAlert> createState() => _AppAlertState();
}

class _AppAlertState extends State<AppAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  static const Color _darkText = Color(0xFF111827);
  static const Color _primaryAccent = Color(0xFF4F70F8);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Slide in immediately
    _controller.forward();

    // Slide out after 4 s, then call onClose at 4.3 s
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) _controller.reverse();
    });
    Future.delayed(const Duration(milliseconds: 4300), () {
      if (mounted) widget.onClose();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── Style helpers ──────────────────────────────────────────────────────────

  Color get _iconColor {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF10B981); // Emerald green for premium feel
      case AlertType.error:
        return const Color(0xFFEF4444); // Crisp red
      case AlertType.warning:
        return const Color(0xFFF59E0B); // Amber
      case AlertType.info:
        return _primaryAccent; // App's primary blue text color
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case AlertType.success:
        return PhosphorIconsRegular.checkCircle;
      case AlertType.error:
        return PhosphorIconsRegular.warningCircle;
      case AlertType.warning:
        return PhosphorIconsRegular.warning;
      case AlertType.info:
        return PhosphorIconsRegular.info;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Pushed slightly higher for a cleaner floating look
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400),
              // Matched padding for pill shapes (wider horizontally)
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white, // Crisp white matching the search bar/pills
                borderRadius: BorderRadius.circular(32), // Pill shape
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04), // App's signature ultra-soft shadow
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_icon, color: _iconColor, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600, // Matched your subtitle weights
                        color: _darkText, // Standardized dark color instead of tinted text
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}