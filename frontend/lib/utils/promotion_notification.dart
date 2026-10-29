String? promotionPropertyRoute(Map<String, dynamic> data) {
  if (data['type']?.toString() != 'property_promotion') return null;
  final propertyId = data['propertyId']?.toString() ?? '';
  const uuidPattern =
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  if (!RegExp(uuidPattern).hasMatch(propertyId)) return null;
  return '/properties/$propertyId';
}

bool isSafePromotionImageUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'res.cloudinary.com' &&
      uri.path.contains('/image/upload/');
}
