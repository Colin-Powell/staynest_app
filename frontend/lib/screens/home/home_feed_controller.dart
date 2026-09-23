import 'package:flutter/material.dart';
import 'package:property_app/models/feed_models.dart';
import 'package:property_app/services/properties_api.dart';

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
      feedResponse = response;
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
