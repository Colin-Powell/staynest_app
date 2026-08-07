import 'package:flutter/material.dart';
import 'package:property_app/utils/property_image_url.dart';

int? sanitizeImageDimension(double? value) {
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }

  return value.toInt();
}

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
    final safeWidth = sanitizeImageDimension(width);
    final safeHeight = sanitizeImageDimension(height);

    return Image.network(
      resolved,
      width: safeWidth?.toDouble(),
      height: safeHeight?.toDouble(),
      fit: fit,
      cacheWidth: safeWidth != null ? (safeWidth * 2) : null,
      cacheHeight: safeHeight != null ? (safeHeight * 2) : null,
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
