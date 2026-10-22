import 'dart:async';

import 'package:flutter/material.dart';
import 'package:property_app/models/feed_models.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';

String describeHomeFeedLoadError(Object error) {
  final message = error.toString();
  final normalized = message.toLowerCase();
  if (error is TimeoutException ||
      normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('clientexception') ||
      normalized.contains('network is unreachable')) {
    return 'No internet connection. Connect to the internet and retry. Saved listings will appear here when available.';
  }
  return 'Could not load properties: $message';
}

class HomeFeedController extends ChangeNotifier {
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  HomeFeedResponse? feedResponse;

  bool _disposed = false;
  int _requestId = 0;
  String? _feedRequestKey;
  double? _lat;
  double? _lng;
  double? _radiusKm;
  String? _campusId;
  String? _locationId;
  String? _category;

  /// Safe wrapper — skips notifyListeners if already disposed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadFeed({
    double? lat,
    double? lng,
    double? radiusKm,
    String? campusId,
    String? locationId,
    String? category,
  }) async {
    if (_disposed) return;

    final requestId = ++_requestId;
    final requestKey = [
      lat,
      lng,
      radiusKm,
      campusId,
      locationId,
      category,
    ].join('|');
    final canKeepCurrentFeed = feedResponse != null &&
        requestKey == _feedRequestKey;

    _lat = lat;
    _lng = lng;
    _radiusKm = radiusKm;
    _campusId = campusId;
    _locationId = locationId;
    _category = category;
    _feedRequestKey = requestKey;

    isLoading = !canKeepCurrentFeed;
    hasError = false;
    errorMessage = null;
    _notify();

    try {
      var receivedResponse = false;
      Object? networkError;
      await PropertiesApi.getHomeFeedCached(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        campusId: campusId,
        locationId: locationId,
        category: category,
        onData: (response, isFromCache) {
          if (_disposed || requestId != _requestId) return;
          receivedResponse = true;
          feedResponse = response;
          isLoading = false;
          hasError = false;
          errorMessage = null;
          _notify();
        },
        onError: (error) => networkError = error,
      );
      if (_disposed || requestId != _requestId) return;

      if (!receivedResponse) {
        hasError = true;
        errorMessage = describeHomeFeedLoadError(
          networkError ?? StateError('No cached home feed was available.'),
        );
        isLoading = false;
        _notify();
        return;
      }

      final response = feedResponse!;
      var sections = response.sections;
      if (AppSession.currentUserId != null && !AppSession.isGuest) {
        try {
          final recentRows = await PropertiesApi.getRecentlyViewed();
          if (recentRows.isNotEmpty) {
            final recentIds = recentRows
                .map((row) => row['id']?.toString())
                .whereType<String>()
                .toSet();
            sections = sections
                .map((section) => section.copyWith(
                      items: section.items
                          .where((property) => !recentIds.contains(property.id))
                          .toList(),
                    ))
                .where((section) => section.items.isNotEmpty)
                .toList();
            sections = [
              FeedSection(
                id: 'recently_viewed',
                type: 'property_carousel',
                title: 'Recently Viewed',
                subtitle: 'Pick up where you left off',
                algorithm: 'recently_viewed_v1',
                items: recentRows.map(mapApiProperty).toList(),
                hasMore: false,
              ),
              ...sections,
            ];
          }
        } catch (e) {
          debugPrint('Error loading recently viewed feed section: $e');
        }
      }
      if (_disposed || requestId != _requestId) return;
      feedResponse = response.copyWith(sections: sections);
    } catch (e) {
      if (_disposed || requestId != _requestId) return;
      debugPrint('Error loading home feed: $e');
      if (feedResponse == null) {
        hasError = true;
        errorMessage = describeHomeFeedLoadError(e);
      }
    } finally {
      if (!_disposed && requestId == _requestId) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> refreshFeed() async {
    await loadFeed(
      lat: _lat,
      lng: _lng,
      radiusKm: _radiusKm,
      campusId: _campusId,
      locationId: _locationId,
      category: _category,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
