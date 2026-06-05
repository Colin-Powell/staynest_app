import 'package:flutter/material.dart';

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

  Color get _bgColor {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFFF0FDF4).withOpacity(0.92);
      case AlertType.error:
        return const Color(0xFFFFF1F2).withOpacity(0.92);
      case AlertType.warning:
        return const Color(0xFFFFFBEB).withOpacity(0.92);
      case AlertType.info:
        return const Color(0xFFEFF6FF).withOpacity(0.92);
    }
  }

  Color get _borderColor {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFFBBF7D0);
      case AlertType.error:
        return const Color(0xFFFECDD3);
      case AlertType.warning:
        return const Color(0xFFFDE68A);
      case AlertType.info:
        return const Color(0xFFBFDBFE);
    }
  }

  Color get _textColor {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF166534);
      case AlertType.error:
        return const Color(0xFF991B1B);
      case AlertType.warning:
        return const Color(0xFF92400E);
      case AlertType.info:
        return const Color(0xFF1E40AF);
    }
  }

  Color get _iconColor {
    switch (widget.type) {
      case AlertType.success:
        return const Color(0xFF22C55E);
      case AlertType.error:
        return const Color(0xFFEF4444);
      case AlertType.warning:
        return const Color(0xFFF59E0B);
      case AlertType.info:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case AlertType.success:
        return Icons.check_circle_outline_rounded;
      case AlertType.error:
        return Icons.error_outline_rounded;
      case AlertType.warning:
        return Icons.warning_amber_rounded;
      case AlertType.info:
        return Icons.info_outline_rounded;
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 24,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_icon, color: _iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textColor,
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

// ─── Usage Helper ─────────────────────────────────────────────────────────────
//
// Wrap your root widget in a Stack and overlay AppAlert using an OverlayEntry
// or manage a List<AppAlert> in state. Minimal example:
//
//   Stack(
//     children: [
//       YourMainContent(),
//       if (_showAlert)
//         AppAlert(
//           type: AlertType.success,
//           message: 'Property published successfully!',
//           onClose: () => setState(() => _showAlert = false),
//         ),
//     ],
//   )