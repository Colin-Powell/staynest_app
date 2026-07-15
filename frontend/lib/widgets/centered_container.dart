import 'package:flutter/widgets.dart';
import 'package:property_app/core/responsive/responsive_layout.dart';

class CenteredContainer extends StatelessWidget {
  const CenteredContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: Padding(
          padding: padding ?? ResponsiveLayout.pageInsets(context),
          child: child,
        ),
      ),
    );
  }
}
