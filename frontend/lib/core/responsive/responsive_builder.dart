import 'package:flutter/widgets.dart';

import 'breakpoints.dart';
import 'device_type.dart';

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  static DeviceType deviceTypeForWidth(double width) {
    if (width <= AppBreakpoints.phoneMax) return DeviceType.phone;
    if (width <= AppBreakpoints.tabletMax) return DeviceType.tablet;
    if (width <= AppBreakpoints.desktopMax) return DeviceType.desktop;
    return DeviceType.largeDesktop;
  }

  static DeviceType of(BuildContext context) {
    return deviceTypeForWidth(AppBreakpoints.widthOf(context));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : AppBreakpoints.widthOf(context);
        return builder(context, deviceTypeForWidth(width));
      },
    );
  }
}
