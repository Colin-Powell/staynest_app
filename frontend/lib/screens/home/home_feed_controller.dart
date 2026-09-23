import 'package:flutter/material.dart';
import 'package:property_app/models/feed_models.dart';
import 'package:property_app/services/properties_api.dart';

class HomeFeedController extends ChangeNotifier {
  bool isLoading = true;
  bool hasError = false;
  HomeFeedResponse? feedResponse;

  Future<void> loadFeed({
    double? lat,
    double? lng,
    String? campusId,
  }) async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      final response = await PropertiesApi.getHomeFeed(
        lat: lat,
        lng: lng,
        campusId: campusId,
      );
      feedResponse = response;
    } catch (e) {
      debugPrint('Error loading home feed: $e');
      hasError = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFeed() async {
    // Retain old feed while refreshing if desired, but here we just reload
    await loadFeed();
  }
}
