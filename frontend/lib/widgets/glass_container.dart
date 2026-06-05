import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:property_app/theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final Color? color;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final double blur;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.color,
    this.border,
    this.onTap,
    this.blur = 24,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.20),
            borderRadius: borderRadius,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
            boxShadow: AppShadow.sm,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}

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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
