import 'package:flutter/material.dart';
import 'package:property_app/models/feed_models.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/utils/property_mapper.dart';

class HomeFeedController extends ChangeNotifier {
  bool isLoading = true;
  bool hasError = false;
  HomeFeedResponse? feedResponse;

  bool _disposed = false;
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

    _lat = lat;
    _lng = lng;
    _radiusKm = radiusKm;
    _campusId = campusId;
    _locationId = locationId;
    _category = category;

    isLoading = true;
    hasError = false;
    _notify();

    try {
      final response = await PropertiesApi.getHomeFeed(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
        campusId: campusId,
        locationId: locationId,
        category: category,
      );
      if (_disposed) return;

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
      feedResponse = response.copyWith(sections: sections);
    } catch (e) {
      if (_disposed) return;
      debugPrint('Error loading home feed: $e');
      hasError = true;
    } finally {
      if (!_disposed) {
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
