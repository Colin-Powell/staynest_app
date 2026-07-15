import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'device_type.dart';
import 'responsive_builder.dart';

abstract final class ResponsiveLayout {
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

  static double pagePadding(BuildContext context) {
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

  static EdgeInsets pageInsets(BuildContext context) {
    final horizontal = pagePadding(context);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: horizontal);
  }

  static int gridColumns(
    BuildContext context, {
    int phone = 1,
    int tablet = 2,
    int desktop = 4,
    int largeDesktop = 4,
  }) {
    switch (deviceType(context)) {
      case DeviceType.phone:
        return phone;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
      case DeviceType.largeDesktop:
        return largeDesktop;
    }
  }
}
