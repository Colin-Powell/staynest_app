import 'package:flutter/foundation.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/local_mock_database_repository.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';

import '../data.dart';

class FallbackPropertiesLoader {
  FallbackPropertiesLoader({
    LocalMockDatabaseRepository repository =
        const LocalMockDatabaseRepository(),
    RemoteDatabaseRepository? remoteRepository,
  })  : _repository = repository,
        _remoteRepository = remoteRepository;

  final LocalMockDatabaseRepository _repository;
  final RemoteDatabaseRepository? _remoteRepository;

  Future<List<Property>> loadAll() async {
    try {
      if (AppSession.isLandlord && AppSession.currentUserId != null) {
        if (_remoteRepository != null) {
          try {
            final ownerProperties = await _remoteRepository!
                .loadPropertiesForUser(AppSession.currentUserId!);
            if (ownerProperties.isNotEmpty) {
              return ownerProperties.map(_propertyFromJson).toList();
            }
          } catch (e, st) {
            debugPrint('Remote owner properties load failed: $e');
            debugPrintStack(stackTrace: st);
          }
        }

        final ownerProperties = await _repository.loadPropertiesForUser(
          AppSession.currentUserId!,
        );
        return ownerProperties.map(_propertyFromJson).toList();
      }

      if (_remoteRepository != null) {
        try {
          final remoteProperties = await _remoteRepository!.loadProperties();
          if (remoteProperties.isNotEmpty) {
            return remoteProperties.map(_propertyFromJson).toList();
          }
        } catch (e, st) {
          debugPrint('Remote properties load failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      final rawProperties = await _repository.loadProperties();
      return rawProperties.map(_propertyFromJson).toList();
    } catch (e, st) {
      debugPrint('FallbackPropertiesLoader.loadAll failed: $e');
      debugPrintStack(stackTrace: st);
      return properties;
    }
  }

  Future<List<Property>> loadByUiCategory(String uiCategory) async {
    try {
      if (_remoteRepository != null) {
        try {
          final categoryData =
              await _remoteRepository!.loadPropertiesByCategory();
          final normalizedUiCategory = _normalizeCategory(uiCategory);

          final hits = <Property>[];
          for (final entry in categoryData.entries) {
            if (_normalizeCategory(entry.key) != normalizedUiCategory) {
              continue;
            }
            hits.addAll(entry.value.map(_propertyFromJson));
          }

          if (hits.isNotEmpty) return hits;
        } catch (e, st) {
          debugPrint('Remote category load failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      final categoryData = await _repository.loadPropertiesByCategory();
      final normalizedUiCategory = _normalizeCategory(uiCategory);

      final hits = <Property>[];
      for (final entry in categoryData.entries) {
        if (_normalizeCategory(entry.key) != normalizedUiCategory) {
          continue;
        }
        hits.addAll(entry.value.map(_propertyFromJson));
      }

      if (hits.isNotEmpty) return hits;

      final all = await loadAll();
      return all
          .where((p) => _normalizeCategory(p.category) == normalizedUiCategory)
          .toList();
    } catch (e, st) {
      debugPrint('FallbackPropertiesLoader.loadByUiCategory failed: $e');
      debugPrintStack(stackTrace: st);
      return properties.where((p) => p.category == uiCategory).toList();
    }
  }

  String _normalizeCategory(String value) => value.trim().toLowerCase();

  Property _propertyFromJson(Map<String, dynamic> m) {
    final featuresMap = Map<String, dynamic>.from(m['features'] as Map);
    final agentMap = Map<String, dynamic>.from(m['agent'] as Map);

    final rawImage = m['image']?.toString() ?? '';

    List<String>? images;
    final dynamic rawImages = m['images'];

    if (rawImages is List) {
      // Back-end may return List<dynamic> (strings or objects).
      images = rawImages
          .map((e) {
            if (e == null) return '';
            if (e is String) return e;
            if (e is Map && e['url'] != null) return e['url'].toString();
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      // Sometimes images is accidentally returned as a single string.
      images = [rawImages];
    }

    // If images list is missing/empty, fall back to single image.
    if (images == null || images.isEmpty) {
      if (rawImage.isNotEmpty) {
        images = [rawImage];
      }
    }

    // Normalize potential double-extension issues: ...jpg.jpg -> ...jpg
    String normalizeUrl(String url) {
      final trimmed = url.trim();
      if (trimmed.endsWith('.jpg.jpg'))
        return trimmed.replaceAll('.jpg.jpg', '.jpg');
      if (trimmed.endsWith('.jpeg.jpeg'))
        return trimmed.replaceAll('.jpeg.jpeg', '.jpeg');
      if (trimmed.endsWith('.png.png'))
        return trimmed.replaceAll('.png.png', '.png');
      return trimmed;
    }

    images = images?.map(normalizeUrl).toList();

    final amenities = (m['amenities'] as List?)?.cast<String>() ?? <String>[];

    return Property(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      name: (m['name'] ?? m['title'] ?? '').toString(),
      location: (m['location'] ?? m['city'] ?? '').toString(),
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      price: (m['price'] as num).toInt(),
      rating: (m['rating'] as num).toDouble(),
      reviews: (m['reviews'] as num).toInt(),
      category: (m['category'] ?? '').toString(),
      image: normalizeUrl(rawImage),
      images: images,
      features: PropertyFeatures(
        beds: (featuresMap['beds'] as num).toInt(),
        rooms: (featuresMap['rooms'] as num).toInt(),
        baths: (featuresMap['baths'] as num).toInt(),
        furnished: featuresMap['furnished'] as bool,
      ),
      amenities: amenities,
      description: m['description']?.toString() ?? '',
      agent: Agent(
        userId:
            agentMap['user_id']?.toString() ?? agentMap['id']?.toString() ?? '',
        name: agentMap['name']?.toString() ?? '',
        avatar: agentMap['avatar']?.toString() ?? '',
      ),
    );
  }
}
