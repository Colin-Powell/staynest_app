import 'package:flutter/widgets.dart';
import 'package:property_app/core/responsive/responsive_layout.dart';

class AdaptivePadding extends StatelessWidget {
  const AdaptivePadding({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? ResponsiveLayout.pageInsets(context),
      child: child,
    );
  }
}
