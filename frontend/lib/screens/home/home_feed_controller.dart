import 'package:flutter/material.dart';
import 'package:property_app/models/feed_models.dart';
import 'package:property_app/services/properties_api.dart';

class HomeFeedController extends ChangeNotifier {
  bool isLoading = true;
  bool hasError = false;
  HomeFeedResponse? feedResponse;

  bool _disposed = false;

  /// Safe wrapper — skips notifyListeners if already disposed.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadFeed({
    double? lat,
    double? lng,
    String? campusId,
  }) async {
    if (_disposed) return;

    isLoading = true;
    hasError = false;
    _notify();

    try {
      final response = await PropertiesApi.getHomeFeed(
        lat: lat,
        lng: lng,
        campusId: campusId,
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
    await loadFeed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
