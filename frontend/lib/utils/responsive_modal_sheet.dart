import 'package:flutter/material.dart';

Future<T?> showResponsiveModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
}) {
  if (MediaQuery.sizeOf(context).width < 768) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      builder: builder,
    );
  }

  final size = MediaQuery.sizeOf(context);
  final viewInsets = MediaQuery.viewInsetsOf(context);
  final maxWidth = (size.width - 48).clamp(0.0, 640.0).toDouble();
  final maxHeight =
      (size.height - viewInsets.bottom - 48).clamp(0.0, 760.0).toDouble();

  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    routeSettings: routeSettings,
    builder: (dialogContext) => AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(dialogContext).bottom,
      ),
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: backgroundColor,
        elevation: elevation ?? 16,
        clipBehavior: clipBehavior ?? Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: maxWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: builder(dialogContext),
          ),
        ),
      ),
    ),
  );
}
