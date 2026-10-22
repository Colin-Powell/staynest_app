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
  static const int _pageSize = 8;

  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasError = false;
  String? errorMessage;
  HomeFeedResponse? feedResponse;
  String? nextCursor;

  bool get hasMore => nextCursor != null;

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
    final canKeepCurrentFeed =
        feedResponse != null && requestKey == _feedRequestKey;

    _lat = lat;
    _lng = lng;
    _radiusKm = radiusKm;
    _campusId = campusId;
    _locationId = locationId;
    _category = category;
    _feedRequestKey = requestKey;
    nextCursor = null;
    isLoadingMore = false;

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
        limit: _pageSize,
        onData: (response, isFromCache) {
          if (_disposed || requestId != _requestId) return;
          receivedResponse = true;
          feedResponse = response;
          nextCursor = response.nextCursor;
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

  Future<void> loadMore() async {
    final cursor = nextCursor;
    final requestId = _requestId;
    if (_disposed || cursor == null || isLoadingMore || feedResponse == null) {
      return;
    }

    isLoadingMore = true;
    _notify();
    try {
      await PropertiesApi.getHomeFeedCached(
        lat: _lat,
        lng: _lng,
        radiusKm: _radiusKm,
        campusId: _campusId,
        locationId: _locationId,
        category: _category,
        limit: _pageSize,
        cursor: cursor,
        onData: (page, isFromCache) {
          if (_disposed || requestId != _requestId) return;
          final currentSections = {
            for (final section in feedResponse!.sections)
              section.id: section.copyWith(hasMore: false),
          };
          for (final section in page.sections) {
            final current = currentSections[section.id];
            if (current == null) {
              currentSections[section.id] = section;
              continue;
            }
            final seenIds = current.items.map((item) => item.id).toSet();
            currentSections[section.id] = current.copyWith(
              items: [
                ...current.items,
                ...section.items.where((item) => seenIds.add(item.id)),
              ],
              hasMore: section.hasMore,
              nextCursor: section.nextCursor,
            );
          }
          feedResponse = HomeFeedResponse(
            schemaVersion: page.schemaVersion,
            generatedAt: page.generatedAt,
            context: page.context,
            sections: currentSections.values.toList(),
            nextCursor: page.nextCursor,
          );
          nextCursor = page.nextCursor;
          _notify();
        },
        onError: (error) => debugPrint('Could not load more home feed: $error'),
      );
    } catch (error) {
      debugPrint('Could not load more home feed: $error');
    } finally {
      if (!_disposed && requestId == _requestId) {
        isLoadingMore = false;
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
