import 'package:flutter/widgets.dart';
import 'package:property_app/core/responsive/responsive_layout.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 4,
    this.largeDesktopColumns = 4,
    this.spacing = 16,
    this.runSpacing,
    this.childAspectRatio = 0.78,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final List<Widget> children;
  final int phoneColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  final double spacing;
  final double? runSpacing;
  final double childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveLayout.gridColumns(
          context,
          phone: phoneColumns,
          tablet: tabletColumns,
          desktop: desktopColumns,
          largeDesktop: largeDesktopColumns,
        ),
        mainAxisSpacing: runSpacing ?? spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) => children[index],
    );
  }
}
