import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:property_app/session/app_session.dart';

class AnalyticsEvents {
  static const String signUp = 'sign_up';
  static const String login = 'login';
  static const String logout = 'logout';
  
  static const String screenView = 'screen_view';
  
  static const String search = 'search';
  static const String filterApplied = 'filter_applied';
  static const String categorySelected = 'category_selected';
  
  static const String listingImpression = 'listing_impression';
  static const String listingView = 'listing_view';
  static const String listingEngagement = 'listing_engagement';
  static const String listingSave = 'listing_save';
  static const String listingUnsave = 'listing_unsave';
  static const String listingShare = 'listing_share';
  static const String listingContact = 'listing_contact';
  static const String galleryInteraction = 'gallery_interaction';
  
  static const String promotionImpression = 'promotion_impression';
  static const String promotionSelected = 'promotion_selected';
  static const String recentListingSelected = 'recent_listing_selected';

  static const String landlordContacted = 'landlord_contacted';

  static const String listingClick = 'listing_click';
}

class AnalyticsParameters {
  static const String method = 'method';
  static const String screenName = 'screen_name';
  static const String screenClass = 'screen_class';
  
  static const String searchTerm = 'search_term';
  static const String location = 'location';
  static const String propertyType = 'property_type';
  static const String minPrice = 'min_price';
  static const String maxPrice = 'max_price';
  static const String amenitiesCount = 'amenities_count';
  static const String resultCount = 'result_count';
  
  static const String listingId = 'listing_id';
  static const String priceBand = 'price_band';
  static const String source = 'source';
  static const String position = 'position';
  static const String durationSeconds = 'duration_seconds';
  
  static const String promotionId = 'promotion_id';
  static const String promotionType = 'promotion_type';
  static const String placement = 'placement';
}

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> initialize() async {
    try {
      await setUserId(AppSession.currentUserId);
    } catch (e) {
      debugPrint('Firebase Analytics initialization failed: ');
    }
  }

  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Firebase Analytics user reset failed: ');
    }
  }

  static Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    try {
      final safeParams = <String, Object>{};
      parameters?.forEach((key, value) {
        if (value != null) {
          if (value is String || value is num || value is bool) {
            safeParams[key] = value;
          } else {
            safeParams[key] = value.toString();
          }
        }
      });
      await _analytics.logEvent(name: name, parameters: safeParams);
    } catch (e) {
      debugPrint('Analytics logEvent failed: ');
    }
  }

  static Future<void> logAuthEvent(String eventName, {required String method}) async {
    await logEvent(eventName, {AnalyticsParameters.method: method});
  }

  static Future<void> logScreenView(String screenName, [String? screenClass]) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('Analytics logScreenView failed: ');
    }
  }

  static Future<void> logSearch({
    String? searchTerm,
    String? location,
    String? propertyType,
  }) async {
    await logEvent(AnalyticsEvents.search, {
      AnalyticsParameters.searchTerm: searchTerm,
      AnalyticsParameters.location: location,
      AnalyticsParameters.propertyType: propertyType,
    });
  }
  
  static Future<void> logListingInteraction(
    String eventName, {
    required String listingId,
    String? source,
    String? propertyType,
    String? location,
    int? durationSeconds,
    int? position,
  }) async {
    await logEvent(eventName, {
      AnalyticsParameters.listingId: listingId,
      AnalyticsParameters.source: source,
      AnalyticsParameters.propertyType: propertyType,
      AnalyticsParameters.location: location,
      AnalyticsParameters.durationSeconds: durationSeconds,
      AnalyticsParameters.position: position,
    });
  }

  static void trackPropertyShare(String s) {}

  static void trackPropertyView(String propertyId, {required String source}) {}
}

class AnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  void _sendScreenView(PageRoute<dynamic> route) {
    var screenName = route.settings.name;
    if (screenName != null) {
      if (screenName.startsWith('/')) {
        screenName = screenName.substring(1);
      }
      if (screenName.isEmpty) screenName = 'home';
      AnalyticsService.logScreenView(screenName);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _sendScreenView(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _sendScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      _sendScreenView(previousRoute);
    }
  }
}
