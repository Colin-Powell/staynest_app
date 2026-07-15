import 'package:flutter/material.dart';
import 'package:property_app/core/responsive/breakpoints.dart';
import 'package:property_app/core/responsive/device_type.dart';
import 'package:property_app/core/responsive/responsive_builder.dart';
import 'package:property_app/theme.dart';

enum ResponsiveBreakpoint { compact, medium, expanded }

class ResponsiveLayout {
  static const double mobileMaxWidth = AppBreakpoints.phoneMax;
  static const double tabletMaxWidth = AppBreakpoints.tabletMax;

  static DeviceType deviceType(BuildContext context) =>
      ResponsiveBuilder.of(context);

  static bool isPhone(BuildContext context) =>
      deviceType(context) == DeviceType.phone;
  static bool isTablet(BuildContext context) =>
      deviceType(context) == DeviceType.tablet;
  static bool isDesktop(BuildContext context) =>
      deviceType(context) == DeviceType.desktop;
  static bool isLargeDesktop(BuildContext context) =>
      deviceType(context) == DeviceType.largeDesktop;
  static bool isDesktopOrLarger(BuildContext context) =>
      isDesktop(context) || isLargeDesktop(context);

  static ResponsiveBreakpoint of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= mobileMaxWidth) {
      return ResponsiveBreakpoint.compact;
    }
    if (width <= tabletMaxWidth) {
      return ResponsiveBreakpoint.medium;
    }
    return ResponsiveBreakpoint.expanded;
  }

  static bool isCompact(BuildContext context) =>
      of(context) == ResponsiveBreakpoint.compact;
  static bool isMedium(BuildContext context) =>
      of(context) == ResponsiveBreakpoint.medium;
  static bool isExpanded(BuildContext context) =>
      of(context) == ResponsiveBreakpoint.expanded;

  static double horizontalPadding(BuildContext context) {
    switch (deviceType(context)) {
      case DeviceType.phone:
        return AppBreakpoints.spacingLarge;
      case DeviceType.tablet:
        return AppBreakpoints.spacingXl;
      case DeviceType.desktop:
        return 40;
      case DeviceType.largeDesktop:
        return AppBreakpoints.spacingXxl;
    }
  }

  static EdgeInsetsGeometry pagePadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: horizontalPadding(context));

  static Widget authShell({
    required BuildContext context,
    required Widget child,
    double maxWidth = 520,
  }) {
    final isCompactScreen = isCompact(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isCompactScreen ? 24 : 32,
            isCompactScreen ? 24 : 32,
            isCompactScreen ? 24 : 32,
            isCompactScreen ? 24 : 32,
          ),
          decoration: isCompactScreen
              ? null
              : BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
          child: child,
        ),
      ),
    );
  }

  static Widget centeredPage({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry? padding,
    double maxWidth = 720,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? pagePadding(context),
          child: child,
        ),
      ),
    );
  }

  static Widget contentFrame({
    required BuildContext context,
    required Widget child,
    double maxWidth = 1120,
    EdgeInsetsGeometry? padding,
    Color? backgroundColor,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          width: double.infinity,
          padding: padding ?? pagePadding(context),
          decoration: backgroundColor == null
              ? null
              : BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
          child: child,
        ),
      ),
    );
  }

  static Color surfaceFor(BuildContext context) {
    return isCompact(context) ? AppColors.white : AppColors.background;
  }
}
