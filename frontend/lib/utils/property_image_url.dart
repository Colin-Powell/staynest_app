import 'package:property_app/session/app_session.dart';

/// Resolves property image paths from API responses into loadable URLs.
String resolvePropertyImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('assets/')) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    // Cloudinary sometimes stores asset versions with a trailing `.jpg` even when the resource is actually `.../name`.
    // Your runtime error shows the correct public id is missing the `.jpg` suffix.
    // Example failing URL:
    // https://res.cloudinary.com/.../image/upload/.../1780-scaled-... .jpg
    // but Cloudinary says the correct image id is:
    // staynest/1780-scaled-...
    if (trimmed.contains('cloudinary.com/')) {
      // Cloudinary URLs:
      // - Your DB stores working URLs ending with `.jpg.jpg`
      // - Your failing requests were for the same URL with only `.jpg`
      // So: for Cloudinary URLs, preserve `.jpg.jpg` and `.jpg` as-is.
      // Do NOT strip any trailing `.jpg` for Cloudinary.
      return trimmed;
    }

    return trimmed;
  }

  if (trimmed.startsWith('/')) {
    final base = AppSession.apiBaseUrl;
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base.replaceAll(RegExp(r'/api/?$'), '');
    return '$origin$trimmed';
  }

  // Common backend habit: return server-relative paths without a leading `/`
  // (e.g. "uploads/abc.jpg"). Treat these as relative to API origin.
  if (RegExp(r'^[A-Za-z0-9_\-./]+\.(jpg|jpeg|png|webp|gif|svg)$',
          caseSensitive: false)
      .hasMatch(trimmed)) {
    final base = AppSession.apiBaseUrl;
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base.replaceAll(RegExp(r'/api/?$'), '');
    return '$origin/$trimmed';
  }

  return trimmed;
}

bool isResolvableNetworkImage(String url) {
  final resolved = resolvePropertyImageUrl(url);
  return resolved.startsWith('http://') || resolved.startsWith('https://');
}
