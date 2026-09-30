import 'package:property_app/session/app_session.dart';

String _withCloudinaryOptimizations(String url) {
  if (!url.contains('cloudinary.com/')) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}f_auto,q_auto,fl_progressive,w_900,h_600';
}

String _secureCloudinaryUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri?.scheme == 'http' && uri?.host == 'res.cloudinary.com') {
    return uri!.replace(scheme: 'https').toString();
  }
  return url;
}

/// Resolves property image paths from API responses into loadable URLs.
String resolvePropertyImageUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('assets/')) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final secureUrl = _secureCloudinaryUrl(trimmed);
    // Cloudinary sometimes stores asset versions with a trailing `.jpg` even when the resource is actually `.../name`.
    // Your runtime error shows the correct public id is missing the `.jpg` suffix.
    // Example failing URL:
    // https://res.cloudinary.com/.../image/upload/.../1780-scaled-... .jpg
    // but Cloudinary says the correct image id is:
    // staynest/1780-scaled-...
    if (secureUrl.contains('cloudinary.com/')) {
      // Cloudinary URLs:
      // - Your DB stores working URLs ending with `.jpg.jpg`
      // - Your failing requests were for the same URL with only `.jpg`
      // So: for Cloudinary URLs, preserve `.jpg.jpg` and `.jpg` as-is.
      // Do NOT strip any trailing `.jpg` for Cloudinary.
      return _withCloudinaryOptimizations(secureUrl);
    }

    return secureUrl;
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
  if (RegExp(r'^[A-Za-z0-9_\-./]+\.(jpg|jpeg|png|webp|gif|svg|mp4|mov|webm)$',
          caseSensitive: false)
      .hasMatch(trimmed)) {
    final base = AppSession.apiBaseUrl;
    final origin = base.endsWith('/api')
        ? base.substring(0, base.length - 4)
        : base.replaceAll(RegExp(r'/api/?$'), '');
    return '$origin/$trimmed';
  }

  // Cloudinary public IDs may come through as a relative ID such as
  // `staynest/listing-123` or `staynest/listing-123.jpg`.
  if (trimmed.contains('/') &&
      !trimmed.startsWith('assets/') &&
      !trimmed.startsWith('http')) {
    final publicId = trimmed.contains('.') ? trimmed : '$trimmed.jpg';
    return '${AppSession.cloudinaryBaseUrl}/$publicId';
  }

  return trimmed;
}

/// Resolves property video URLs without applying image transformations.
/// Cloudinary media must use HTTPS on Android; image optimizations can also
/// produce an invalid video source when appended to a video URL.
String resolvePropertyVideoUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  final resolved =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
          ? trimmed
          : resolvePropertyImageUrl(trimmed);

  if (resolved.startsWith('http://') &&
      !resolved.startsWith('http://localhost') &&
      !resolved.startsWith('http://127.0.0.1') &&
      !resolved.startsWith('http://10.0.2.2')) {
    return resolved.replaceFirst(RegExp(r'^http://'), 'https://');
  }

  return resolved;
}

bool isResolvableNetworkImage(String url) {
  final resolved = resolvePropertyImageUrl(url);
  return resolved.startsWith('http://') || resolved.startsWith('https://');
}
