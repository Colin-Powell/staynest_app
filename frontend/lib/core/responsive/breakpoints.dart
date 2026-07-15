import 'package:flutter/widgets.dart';

abstract final class AppBreakpoints {
  static const double phoneMin = 0;
  static const double phoneMax = 599;
  static const double tabletMin = 600;
  static const double tabletMax = 1023;
  static const double desktopMin = 1024;
  static const double desktopMax = 1439;
  static const double largeDesktopMin = 1440;

  static const double loginMaxWidth = 420;
  static const double signupMaxWidth = 480;
  static const double formMaxWidth = 600;
  static const double propertyDetailsMaxWidth = 1200;
  static const double dashboardMaxWidth = 1400;

  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;
}
