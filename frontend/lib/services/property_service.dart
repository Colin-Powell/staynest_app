import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/utils/property_mapper.dart';
import 'package:property_app/screens/home/cache_engine.dart';

class PropertyService {
  // ==========================================
  // DRAFTS (Persistent Backend)
  // ==========================================
  Future<Map<String, dynamic>> saveDraft(Map<String, dynamic> payload, {String? draftId}) async {
    final token = AppSession.apiToken;
    if (token == null) throw Exception('Not authenticated');

    final uri = draftId != null 
        ? Uri.parse('$baseUrl/drafts/$draftId')
        : Uri.parse('$baseUrl/drafts');
        
    final response = await (draftId != null ? http.put : http.post)(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Failed to save draft: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    final token = AppSession.apiToken;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/drafts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to fetch drafts');
    }
  }

  Future<void> deleteDraft(String draftId) async {
    final token = AppSession.apiToken;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/drafts/$draftId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 300) {
      throw Exception('Failed to delete draft');
    }
  }


  static final PropertyService instance = PropertyService._internal();
  PropertyService._internal();

  final String baseUrl = AppSession.apiBaseUrl;

  /// Fetch all properties with optional filters from database
  Future<List<Property>> fetchProperties({
    String? category,
    String? city,
    String? landlordId,
    double? lat,
    double? lng,
    List<String>? history,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (city != null && city.isNotEmpty) queryParams['city'] = city;
      if (landlordId != null && landlordId.isNotEmpty) {
        queryParams['landlordId'] = landlordId;
      }
      if (lat != null && lng != null) {
        queryParams['lat'] = lat.toString();
        queryParams['lng'] = lng.toString();
      }
      if (history != null && history.isNotEmpty) {
        queryParams['history'] = history.join(',');
      }

      final uri = Uri.parse('$baseUrl/properties')
          .replace(queryParameters: queryParams);

      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = AppSession.apiToken;
      if (token?.isNotEmpty == true) {
        headers['Authorization'] = 'Bearer $token';
      }

      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final propertiesList =
            (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final props = propertiesList.map(mapApiProperty).toList();
        for (final p in props) {
          print(
              'PROPERTY: ${p.name} | image: ${p.image} | images: ${p.images}');
        }
        return props;
      }

      throw Exception('Failed to fetch properties: ${res.statusCode}');
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching properties: $e');
      rethrow;
    }
  }

  /// Fetch nearby properties with location
  Future<List<Property>> fetchNearby({
    required double latitude,
    required double longitude,
    String? category,
    List<String>? recentSearches,
  }) async {
    return fetchProperties(
      lat: latitude,
      lng: longitude,
      category: category,
      history: recentSearches,
    );
  }

  /// Fetch recommendations (same as nearby for now)
  Future<List<Property>> fetchRecommendations({
    double? latitude,
    double? longitude,
    List<String>? recentSearches,
  }) async {
    if (latitude != null && longitude != null) {
      return fetchNearby(
        latitude: latitude,
        longitude: longitude,
        recentSearches: recentSearches,
      );
    }
    return fetchProperties(history: recentSearches);
  }

  Future<Property?> fetchPropertyById(String id) async {
    if (id.isEmpty) return null;

    try {
      final cacheKey = CacheKeys.propertyDetail(id);
      final rawData = await CacheEngine.instance.getOrFetch<Map<String, dynamic>>(
        key: cacheKey,
        ttl: CacheTTL.details,
        networkFetcher: () async {
          final uri = Uri.parse('$baseUrl/properties/$id');
          final headers = <String, String>{'Content-Type': 'application/json'};
          final token = AppSession.apiToken;
          if (token?.isNotEmpty == true) {
            headers['Authorization'] = 'Bearer $token';
          }

          final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            final payload = data['data'] as Map<String, dynamic>?;
            if (payload != null) {
              return payload;
            }
          }
          throw Exception('Failed to load property');
        }
      );
      
      return mapApiProperty(rawData);
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching property by id: $e');
      return null;
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      final status = await Geolocator.checkPermission();
      if (status == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied) return null;
      }
      if (await Geolocator.isLocationServiceEnabled()) {
        return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveSearchTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recent_searches') ?? [];
    if (term.trim().isEmpty) return;
    list.remove(term);
    list.insert(0, term);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList('recent_searches', list);
  }

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recent_searches') ?? [];
  }
}
