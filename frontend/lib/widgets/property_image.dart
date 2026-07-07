import 'package:flutter/material.dart';
import 'package:property_app/utils/property_image_url.dart';

Widget buildPropertyImage(
  String imagePath, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorPlaceholder,
}) {
  final placeholder = errorPlaceholder ??
      Container(
        width: width,
        height: height,
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.home_outlined, color: Color(0xFF9CA3AF)),
      );

  final resolved = resolvePropertyImageUrl(imagePath);

  if (resolved.startsWith('assets/')) {
    return Image.asset(
      resolved,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  if (isResolvableNetworkImage(resolved)) {
    return Image.network(
      resolved,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: width != null ? (width * 2).toInt() : null,
      cacheHeight: height != null ? (height * 2).toInt() : null,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) {
        // TODO: Remove debug logging after image stability is confirmed.
        // ignore: avoid_print
        print('IMAGE ERROR: $resolved\nERROR: $error\nSTACK: $stackTrace');
        return placeholder;
      },
    );
  }

  return placeholder;
}
