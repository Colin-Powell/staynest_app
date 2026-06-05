import 'package:flutter/material.dart';

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

  if (imagePath.startsWith('assets/')) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  return Image.network(
    imagePath,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => placeholder,
  );
}
