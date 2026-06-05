import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final double borderWidth;

  const GlassContainer({
    super.key,
    required this.child,
    required this.padding,
    this.borderRadius,
    this.blur = 15.0,
    this.opacity = 0.45,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);

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
              width: borderWidth,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
