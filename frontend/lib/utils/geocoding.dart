import 'dart:convert';

import 'package:http/http.dart' as http;

typedef GeocodingSuggestion = ({
  String displayName,
  double lat,
  double lng,
});

Future<List<GeocodingSuggestion>> searchAddressSuggestions(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.length < 3) return [];

  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'q': trimmedQuery,
      'limit': '5',
      'addressdetails': '1',
    });
    final response = await http.get(uri, headers: {
      'User-Agent': 'StayNest/1.0 (location search)',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];
    final results = json.decode(response.body) as List<dynamic>;
    return results
        .map((result) {
          final item = result as Map<String, dynamic>;
          return (
            displayName: item['display_name']?.toString() ?? '',
            lat: double.tryParse(item['lat']?.toString() ?? '') ?? double.nan,
            lng: double.tryParse(item['lon']?.toString() ?? '') ?? double.nan,
          );
        })
        .where((item) =>
            item.displayName.isNotEmpty &&
            item.lat.isFinite &&
            item.lng.isFinite)
        .toList();
  } catch (_) {
    return [];
  }
}

/// Resolves coordinates for a free-text address using OpenStreetMap Nominatim.
Future<({double lat, double lng})?> geocodeAddress(String query) async {
  if (query.trim().isEmpty) return null;

  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=json&q=${Uri.encodeComponent(query)}&limit=1',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'StayNest/1.0'
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final results = json.decode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat']?.toString() ?? '');
    final lng = double.tryParse(first['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;

    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}
Future<String?> reverseGeocode(double lat, double lng) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'StayNest/1.0',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['display_name']?.toString();
  } catch (_) {
    return null;
  }
}
