import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/session/app_session.dart';

class AnalyticsEvents {
  static const String otpScreenViewed = 'otp_screen_viewed';
  static const String otpVerificationStarted = 'otp_verification_started';
  static const String otpVerificationSuccess = 'otp_verification_success';
  static const String otpVerificationFailed = 'otp_verification_failed';
  static const String otpResendRequested = 'otp_resend_requested';
  static const String otpAutofillUsed = 'otp_autofill_used';
  static const String otpManualEntryUsed = 'otp_manual_entry_used';

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
  static const String beginCheckout = 'begin_checkout';
  static const String bookingCompleted = 'booking_completed';
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
  static FirebaseAnalytics? _analyticsInstance;
  static bool _initialized = false;

  static FirebaseAnalytics? get _analytics {
    if (!_initialized || Firebase.apps.isEmpty) return null;
    return _analyticsInstance ??= FirebaseAnalytics.instance;
  }

  static Future<void> initialize() async {
    try {
      _initialized = true;
      await setUserId(AppSession.currentUserId);
    } catch (e, stackTrace) {
      debugPrint('Firebase Analytics initialization failed: $e\n$stackTrace');
    }
  }

  static Future<void> setUserId(String? userId) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Firebase Analytics user reset failed: $e');
    }
  }

  static Future<void> logEvent(String name,
      [Map<String, Object?>? parameters]) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;

      final safeParams = <String, Object>{};
      parameters?.forEach((key, value) {
        if (value != null) {
          final cleanKey = key.trim().replaceAll(' ', '_');
          final safeKey =
              cleanKey.length > 40 ? cleanKey.substring(0, 40) : cleanKey;

          if (value is num) {
            safeParams[safeKey] = value;
          } else if (value is bool) {
            safeParams[safeKey] = value ? 1 : 0;
          } else {
            final str = value.toString();
            safeParams[safeKey] =
                str.length > 100 ? str.substring(0, 100) : str;
          }
        }
      });
      await analytics.logEvent(name: name, parameters: safeParams);
    } catch (e) {
      debugPrint('Analytics logEvent failed ($name): $e');
    }
  }

  static Future<void> logAuthEvent(String eventName,
      {required String method}) async {
    await logEvent(eventName, {AnalyticsParameters.method: method});
  }

  static Future<void> logScreenView(String screenName,
      [String? screenClass]) async {
    try {
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('Analytics logScreenView failed ($screenName): $e');
    }
  }

  static Future<void> logSearch({
    String? searchTerm,
    String? location,
    String? propertyType,
    int? resultCount,
  }) async {
    await logEvent(AnalyticsEvents.search, {
      AnalyticsParameters.searchTerm: searchTerm,
      AnalyticsParameters.location: location,
      AnalyticsParameters.propertyType: propertyType,
      if (resultCount != null) AnalyticsParameters.resultCount: resultCount,
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
    if (eventName == AnalyticsEvents.listingView) {
      try {
        await PropertiesApi.recordPropertyView(listingId);
      } catch (e) {
        debugPrint('PropertiesApi.recordPropertyView failed: $e');
      }
    }

    await logEvent(eventName, {
      AnalyticsParameters.listingId: listingId,
      AnalyticsParameters.source: source,
      AnalyticsParameters.propertyType: propertyType,
      AnalyticsParameters.location: location,
      AnalyticsParameters.durationSeconds: durationSeconds,
      AnalyticsParameters.position: position,
    });
  }

  static Future<void> trackPropertyShare(String propertyId) async {
    if (propertyId.isEmpty) return;
    try {
      await PropertiesApi.trackPropertyShare(propertyId);
    } catch (e) {
      debugPrint('Property share tracking failed: $e');
    }
    await logListingInteraction(
      AnalyticsEvents.listingShare,
      listingId: propertyId,
    );
  }

  static Future<void> trackPropertyView(
    String propertyId, {
    required String source,
    String? propertyType,
    String? location,
  }) async {
    if (propertyId.isEmpty) return;
    await logListingInteraction(
      AnalyticsEvents.listingView,
      listingId: propertyId,
      source: source,
      propertyType: propertyType,
      location: location,
    );
  }
}

class AnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  void _sendScreenView(PageRoute<dynamic> route) {
    var screenName = route.settings.name;
    if (screenName != null) {
      if (screenName.startsWith('/')) {
        screenName = screenName.substring(1);
      }
      if (screenName.isEmpty) screenName = 'splash';
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
