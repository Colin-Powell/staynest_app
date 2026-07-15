import 'dart:ui';
import 'package:flutter/material.dart';

// Local lightweight shadow to avoid coupling to theme internals.
// (Some parts of the app don't expose a single AppShadow symbol.)
List<BoxShadow> _smShadows() => const [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 20,
        offset: Offset(0, 4),
      ),
    ];


/// Reusable glassmorphism container used across the app.
///
/// Provides defaults for all visual parameters so callers never need to
/// initialize every field (fixes "Final field ... is not initialized").
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;


  /// Blur sigma for BackdropFilter.
  final double blur;

  /// Background overlay opacity (0..1).
  final double opacity;

  /// Convenience for border width when [border] is not provided.
  final double borderWidth;

  /// Optional fixed height.
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color,
    this.border,
    this.onTap,
    this.blur = 24,
    this.opacity = 0.20,
    this.borderWidth = 1.2,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(opacity),
            borderRadius: borderRadius,
            border: border ??
                Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: borderWidth,
                ),
            boxShadow: _smShadows(),
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Optional helper button that uses [GlassContainer].
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF69B071),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.90),
        border: Border.all(color: color.withOpacity(0.18), width: 1.2),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
