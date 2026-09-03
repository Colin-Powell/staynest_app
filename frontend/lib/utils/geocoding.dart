import 'dart:convert';

import 'package:http/http.dart' as http;

typedef GeocodingSuggestion = ({
  String displayName,
  double lat,
  double lng,
  String? country,
  String? county,
  String? subCounty,
  String? ward,
  String? town,
  String? neighborhood,
  String? estateOrVillage,
  String? road,
  String? landmark,
});

String? _value(Map<String, dynamic> address, String key) {
  final value = address[key]?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

GeocodingSuggestion? _parseSuggestion(Map<String, dynamic> item) {
  final displayName = item['display_name']?.toString() ?? '';
  final lat = double.tryParse(item['lat']?.toString() ?? '');
  final lng = double.tryParse(item['lon']?.toString() ?? '');
  final rawAddress = item['address'];
  final address = rawAddress is Map
      ? Map<String, dynamic>.from(rawAddress)
      : <String, dynamic>{};
  if (displayName.isEmpty || lat == null || lng == null) return null;

  // Kenya's OSM data uses both administrative and place-specific keys.
  return (
    displayName: displayName,
    lat: lat,
    lng: lng,
    country: _value(address, 'country'),
    county: _value(address, 'state') ?? _value(address, 'county'),
    subCounty: _value(address, 'state_district') ?? _value(address, 'county'),
    ward: _value(address, 'city') ?? _value(address, 'city_district'),
    town: _value(address, 'town') ??
        _value(address, 'city') ??
        _value(address, 'municipality'),
    neighborhood: _value(address, 'suburb') ?? _value(address, 'quarter'),
    estateOrVillage:
        _value(address, 'residential') ?? _value(address, 'village'),
    road: _value(address, 'road'),
    landmark: _value(address, 'amenity') ??
        _value(address, 'tourism') ??
        _value(address, 'shop'),
  );
}

GeocodingSuggestion? _parsePhotonFeature(Map<String, dynamic> feature) {
  final properties = feature['properties'];
  final geometry = feature['geometry'];
  if (properties is! Map || geometry is! Map) return null;
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.length < 2) return null;

  final longitude = double.tryParse(coordinates[0].toString());
  final latitude = double.tryParse(coordinates[1].toString());
  if (latitude == null || longitude == null) return null;

  final values = Map<String, dynamic>.from(properties);
  final country = _value(values, 'country');
  if (country?.toLowerCase() != 'kenya') return null;

  final name = _value(values, 'name');
  final street = _value(values, 'street');
  final city = _value(values, 'city') ?? _value(values, 'district');
  final state = _value(values, 'state');
  final displayName = [
    name,
    street,
    city,
    state,
    country,
  ].whereType<String>().toSet().join(', ');
  if (displayName.isEmpty) return null;

  return (
    displayName: displayName,
    lat: latitude,
    lng: longitude,
    country: country,
    county: state,
    subCounty: _value(values, 'county') ?? _value(values, 'district'),
    ward: _value(values, 'locality'),
    town: city,
    neighborhood: _value(values, 'suburb') ?? _value(values, 'quarter'),
    estateOrVillage: _value(values, 'village') ?? _value(values, 'residential'),
    road: street,
    landmark: null,
  );
}

String _normalizeToken(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

int _matchScore(GeocodingSuggestion suggestion, List<String> tokens) {
  final haystack = _normalizeToken([
    suggestion.displayName,
    suggestion.county,
    suggestion.subCounty,
    suggestion.ward,
    suggestion.town,
    suggestion.neighborhood,
    suggestion.estateOrVillage,
    suggestion.road,
  ].whereType<String>().join(' '));
  return tokens.where((token) => haystack.contains(token)).length;
}

Future<List<GeocodingSuggestion>> _searchNominatim(String query) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
    'format': 'jsonv2',
    'q': query,
    'limit': '5',
    'addressdetails': '1',
    'countrycodes': 'ke',
  });
  final response = await http.get(uri, headers: {
    'User-Agent': 'StayNest/1.0 (location search)',
    'Accept-Language': 'en',
  }).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return [];
  final results = json.decode(response.body) as List<dynamic>;
  return results
      .whereType<Map>()
      .map((result) => _parseSuggestion(Map<String, dynamic>.from(result)))
      .whereType<GeocodingSuggestion>()
      .where((item) => item.country?.toLowerCase() == 'kenya')
      .toList();
}

Future<List<GeocodingSuggestion>> _searchPhoton(String query) async {
  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': '$query Kenya',
    'limit': '8',
  });
  final response = await http.get(uri, headers: {
    'User-Agent': 'StayNest/1.0 (location search)',
    'Accept-Language': 'en',
  }).timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return [];
  final data = json.decode(response.body) as Map<String, dynamic>;
  final features = data['features'];
  if (features is! List) return [];
  return features
      .whereType<Map>()
      .map((feature) => _parsePhotonFeature(Map<String, dynamic>.from(feature)))
      .whereType<GeocodingSuggestion>()
      .toList();
}

Future<List<GeocodingSuggestion>> searchAddressSuggestions(String query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.length < 3) return [];

  try {
    final tokens = _normalizeToken(trimmedQuery)
        .split(' ')
        .where((token) => token.length >= 2 && token != 'kenya')
        .toList();
    final nominatimResults = await _searchNominatim(trimmedQuery);
    final photonResults = nominatimResults.isNotEmpty
        ? <GeocodingSuggestion>[]
        : await _searchPhoton(trimmedQuery);
    final combined = [...nominatimResults, ...photonResults];
    final unique = <String, GeocodingSuggestion>{};
    for (final suggestion in combined) {
      final key =
          '${suggestion.lat.toStringAsFixed(5)},${suggestion.lng.toStringAsFixed(5)}';
      unique[key] = suggestion;
    }
    final ranked = unique.values.toList()
      ..sort(
          (a, b) => _matchScore(b, tokens).compareTo(_matchScore(a, tokens)));
    return ranked.take(5).toList();
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
  final suggestion = await reverseGeocodeSuggestion(lat, lng);
  return suggestion?.displayName;
}

Future<GeocodingSuggestion?> reverseGeocodeSuggestion(
    double lat, double lng) async {
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&addressdetails=1&lat=$lat&lon=$lng',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'StayNest/1.0',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    return _parseSuggestion(data);
  } catch (_) {
    return null;
  }
}
