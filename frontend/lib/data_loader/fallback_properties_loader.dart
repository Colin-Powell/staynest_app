import 'package:flutter/foundation.dart';

import 'package:property_app/models/property.dart';
import 'package:property_app/repository/local_mock_database_repository.dart';
import 'package:property_app/repository/remote_database_repository.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/property_mapper.dart';

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

  Future<List<dynamic>> loadAll() async {
    try {
      // Landlord: try remote first, then local mock.
      if (AppSession.isLandlord && AppSession.currentUserId != null) {
        if (_remoteRepository != null) {
          try {
            final ownerProperties = await _remoteRepository!
                .loadPropertiesForUser(AppSession.currentUserId!);
            if (ownerProperties.isNotEmpty) {
              return ownerProperties.map(mapApiProperty).toList();
            }
          } catch (e, st) {
            debugPrint('Remote owner properties load failed: $e');
            debugPrintStack(stackTrace: st);
          }
        }

        final ownerProperties =
            await _repository.loadPropertiesForUser(AppSession.currentUserId!);
        return ownerProperties.map(mapApiProperty).toList();
      }

      // Everyone: try remote first, then local mock.
      if (_remoteRepository != null) {
        try {
          final remoteProperties = await _remoteRepository!.loadProperties();
          if (remoteProperties.isNotEmpty) {
            return remoteProperties.map(mapApiProperty as Function(Property e)).toList();
          }
        } catch (e, st) {
          debugPrint('Remote properties load failed: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      final rawProperties = await _repository.loadProperties();
      return rawProperties.map(mapApiProperty).toList();
    } catch (e, st) {
      debugPrint('FallbackPropertiesLoader.loadAll failed: $e');
      debugPrintStack(stackTrace: st);
      return properties;
    }
  }

  Future<List<dynamic>> loadByUiCategory(String uiCategory) async {
    try {
      if (_remoteRepository != null) {
        try {
          final categoryData =
              await _remoteRepository!.loadPropertiesByCategory();
          final normalizedUiCategory = _normalizeCategory(uiCategory);

          final hits = <Property>[];
          for (final entry in categoryData.entries) {
            if (_normalizeCategory(entry.key) != normalizedUiCategory) continue;
            hits.addAll(entry.value.map(mapApiProperty));
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
        if (_normalizeCategory(entry.key) != normalizedUiCategory) continue;
        hits.addAll(entry.value.map(mapApiProperty));
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
}
