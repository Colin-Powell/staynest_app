import 'dart:convert';

import 'package:property_app/models/property.dart';
import 'package:property_app/utils/property_image_url.dart';

/// Maps API JSON (flat backend shape or legacy mock shape) to the UI [Property] model.
Property mapApiProperty(Map<String, dynamic> json) {
  final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';

  final name =
      json['title']?.toString() ?? json['name']?.toString() ?? 'Unknown';

  final city = json['city']?.toString() ?? '';
  final address = json['address']?.toString() ?? '';
  final location = address.isNotEmpty
      ? (city.isNotEmpty ? '$address, $city' : address)
      : (json['location']?.toString() ?? (city.isNotEmpty ? city : 'Unknown'));

  final images = _extractImages(json);
  final rawImage =
      json['image']?.toString() ?? json['image_url']?.toString() ?? '';
  final image = images.isNotEmpty
      ? images.first
      : _normalizeUrl(resolvePropertyImageUrl(rawImage));

  final amenities = _extractAmenities(json);
  final furnished = amenities.any(
    (a) => a.toLowerCase().contains('furnish'),
  );

  final featuresMap = json['features'];
  final beds = featuresMap is Map
      ? _toInt(featuresMap['beds'])
      : _toInt(json['bedrooms']);
  final baths = featuresMap is Map
      ? _toInt(featuresMap['baths'])
      : _toInt(json['bathrooms']);
  final rooms = featuresMap is Map ? _toInt(featuresMap['rooms']) : beds + 1;
  final featuresFurnished =
      featuresMap is Map && featuresMap['furnished'] is bool
          ? featuresMap['furnished'] as bool
          : furnished;

  final agentMap = json['agent'];
  final agent = Agent(
    userId: agentMap is Map
        ? (agentMap['user_id']?.toString() ?? agentMap['id']?.toString() ?? '')
        : json['landlord_id']?.toString() ?? '',
    name: agentMap is Map
        ? agentMap['name']?.toString() ?? 'Agent'
        : json['landlord_name']?.toString() ?? 'Agent',
    avatar: resolvePropertyImageUrl(
      agentMap is Map
          ? agentMap['avatar']?.toString() ?? ''
          : json['landlord_avatar']?.toString() ?? '',
    ),
    verified: json['landlord_verified'] == true,
    email: json['landlord_email']?.toString(),
    businessName: json['landlord_business_name']?.toString(),
    businessDescription: json['landlord_business_description']?.toString(),
    memberSince: json['landlord_member_since']?.toString(),
    propertyCount: _toInt(json['landlord_property_count']),
  );

  // Backend `/properties` returns `review_count` and `average_rating`.
  // Keep backwards compatibility with legacy keys `reviews`/`rating`.
  final reviews = (json['review_count'] ?? json['reviews']) is num
      ? ((json['review_count'] ?? json['reviews']) as num).toInt()
      : int.tryParse(
              (json['review_count'] ?? json['reviews'])?.toString() ?? '') ??
          0;

  final ratingRaw = json['average_rating'] ?? json['rating'];
  final rating = ratingRaw is num
      ? ratingRaw.toDouble()
      : double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0;

  return Property(
    id: id,
    name: name,
    location: location,
    lat: _toDouble(json['lat']),
    lng: _toDouble(json['lng']),
    price: _toInt(json['price']),
    rating: rating,
    reviews: reviews,
    category: json['category']?.toString() ?? 'Apartment',
    image: image,
    images: images.isNotEmpty ? images : (image.isNotEmpty ? [image] : null),
    videoUrl: json['video_url']?.toString(),
    features: PropertyFeatures(
      beds: beds,
      rooms: rooms,
      baths: baths,
      furnished: featuresFurnished,
      area: _toInt(json['area']),
    ),
    amenities: amenities.where((a) => !a.startsWith('custom:')).toList(),
    customFeatures: amenities
        .where((a) => a.startsWith('custom:'))
        .map((a) => a.substring(7))
        .toList(),
    description: json['description']?.toString() ?? '',
    agent: agent,
    viewedAt: json['viewed_at'] != null
        ? DateTime.tryParse(json['viewed_at'].toString())
        : null,
  );
}

List<String> _extractImages(Map<String, dynamic> json) {
  final rawImages = _coerceJsonList(json['images'] ?? json['photos']);
  if (rawImages.isNotEmpty) {
    return rawImages
        .map((e) {
          if (e == null) return '';
          if (e is String) return _normalizeUrl(resolvePropertyImageUrl(e));
          if (e is Map && e['url'] != null) {
            return _normalizeUrl(resolvePropertyImageUrl(e['url'].toString()));
          }
          return _normalizeUrl(resolvePropertyImageUrl(e.toString()));
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  final imageUrl = json['image_url']?.toString();
  if (imageUrl != null && imageUrl.trim().isNotEmpty) {
    return [_normalizeUrl(resolvePropertyImageUrl(imageUrl))];
  }

  final image = json['image']?.toString();
  if (image != null && image.trim().isNotEmpty) {
    return [_normalizeUrl(resolvePropertyImageUrl(image))];
  }

  return [];
}

List<dynamic> _coerceJsonList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
  }
  return const [];
}

List<String> _extractAmenities(Map<String, dynamic> json) {
  final raw = _coerceJsonList(json['amenities']);
  if (raw.isNotEmpty) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}

String _normalizeUrl(String url) {
  final trimmed = url.trim();
  // Preserve double extensions (Cloudinary DB format): .jpg.jpg, etc.
  // Some UI screens expect the exact stored URL; rewriting breaks images.
  return trimmed;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
