import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:property_app/session/app_session.dart';

class AnalyticsService {
  static String get _baseUrl => '${AppSession.apiBaseUrl}/analytics';
  static String? _sessionId;

  static String get sessionId => _sessionId ??= const Uuid().v4();

  // Anti-duplication state: Source -> Set of Property IDs seen in this session
  static final Map<String, Set<String>> _sessionImpressions = {};

  /// Resets the seen impressions for a fresh tracking session (e.g. on new search or filter)
  static void resetSessionImpressions() {
    _sessionImpressions.clear();
  }

  /// Tracks tenant behavior for Product Intelligence
  static Future<void> logEvent({
    required String eventType,
    String? userId,
    required String propertyId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode({
          'eventType': eventType,
          'userId': userId ?? AppSession.currentUserId, // Send null for guests to satisfy UUID constraint
          'propertyId': propertyId,
          'sessionId': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
          'metadata': metadata,
        }),
      );
    } catch (e) {
      print('Failed to log analytics: $e');
    }
  }

  /// Non-blocking tracker wrappers with event source attribution
  static void trackPropertyView(String propertyId,
          {String? userId, String? source}) =>
      logEvent(
          eventType: 'property_view',
          userId: userId,
          propertyId: propertyId,
          metadata: {'source': source ?? 'direct'});

  /// Tracks when a property is opened in detail view (once per session per property)
  static void trackPropertyDetailView(String propertyId, {String? userId}) {
    const event = 'property_detail_view';
    _sessionImpressions.putIfAbsent(event, () => {});
    if (_sessionImpressions[event]!.contains(propertyId)) return;
    _sessionImpressions[event]!.add(propertyId);

    logEvent(
        eventType: event,
        userId: userId,
        propertyId: propertyId,
        metadata: {
          'source': 'detail_entry',
          'timestamp': DateTime.now().toIso8601String(),
        });
  }

  /// Primary impression tracker with anti-duplication and rich metadata
  static void trackPropertyImpression(String propertyId,
          {String? userId, String? source, int? position, String? query, Map<String, dynamic>? filters, String? eventOverride}) {
    
    final sourceKey = source ?? 'search';
    final eventType = eventOverride ?? 'property_impression';
    
    _sessionImpressions.putIfAbsent(sourceKey, () => {});
    
    // Anti-duplication rule: Only once per session per property per source
    if (_sessionImpressions[sourceKey]!.contains(propertyId)) return;
    _sessionImpressions[sourceKey]!.add(propertyId);

    logEvent(
        eventType: eventType,
        userId: userId,
        propertyId: propertyId,
        metadata: {
          'source': sourceKey,
          'position': position,
          'query': query,
          'filters': filters,
          'timestamp': DateTime.now().toIso8601String(),
        });
  }

  static void trackFeaturedPropertyImpression(String propertyId, {int? position}) =>
      trackPropertyImpression(propertyId, source: 'home_featured', position: position, eventOverride: 'featured_property_impression');

  static void trackMapPropertyImpression(String propertyId) =>
      trackPropertyImpression(propertyId, source: 'map', eventOverride: 'map_property_impression');

  static void trackRecommendedPropertyImpression(String propertyId, String sourcePropertyId, {int? position}) {
    const event = 'recommended_property_impression';
    _sessionImpressions.putIfAbsent(event, () => {});
    if (_sessionImpressions[event]!.contains(propertyId)) return;
    _sessionImpressions[event]!.add(propertyId);

    logEvent(
      eventType: event,
      propertyId: propertyId,
      metadata: {
        'source': 'recommended',
        'source_property_id': sourcePropertyId,
        'position': position,
        'timestamp': DateTime.now().toIso8601String(),
      }
    );
  }

  static void trackSavedPropertyImpression(String propertyId, {int? position}) =>
      trackPropertyImpression(propertyId, source: 'saved', position: position, eventOverride: 'saved_property_impression');

  static void trackOwnerPropertyImpression(String propertyId) =>
      trackPropertyImpression(propertyId, source: 'owner_preview', eventOverride: 'owner_property_impression');

  static void trackChatInitiated(String propertyId,
          {String? userId, String? source}) =>
      logEvent(
          eventType: 'chat_started',
          userId: userId,
          propertyId: propertyId,
          metadata: {'source': source});

  static void trackBookingRequest(String propertyId,
          {String? userId, String? source}) =>
      logEvent(
          eventType: 'booking_requested',
          userId: userId,
          propertyId: propertyId,
          metadata: {'source': source});

  static void trackPropertyClick(String propertyId,
          {String? userId, String? source}) =>
      logEvent(
          eventType: 'property_click',
          userId: userId,
          propertyId: propertyId,
          metadata: {'source': source});

  static void trackPropertySave(String propertyId, {String? userId}) =>
      logEvent(eventType: 'property_save', userId: userId, propertyId: propertyId);

  static void trackPropertyShare(String propertyId, {String? userId}) =>
      logEvent(eventType: 'property_share', userId: userId, propertyId: propertyId);

  // 4. Conversion Funnel Tracking
  static void trackFunnelStep(String step, String propertyId, {String? userId}) =>
      logEvent(
          eventType: 'funnel_$step', userId: userId, propertyId: propertyId);

  // 5. Time-Based Tracking
  static void trackTimeSpent(
          String propertyId, String userId, int seconds, String section) =>
      logEvent(
          eventType: 'time_spent',
          userId: userId,
          propertyId: propertyId,
          metadata: {'seconds': seconds, 'section': section});

  /// Fetches engagement statistics for a property to display to the landlord
  static Future<Map<String, dynamic>?> getPropertyEngagementStats(
      String propertyId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/$propertyId'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch stats: $e');
    }
    return null;
  }

  /// Fetches aggregated analytics for a landlord portfolio
  static Future<Map<String, dynamic>?> getLandlordOverview(
      String filter) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/landlord-overview?filter=$filter'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch landlord overview: $e');
    }
    return null;
  }

  /// Provides structured mock data for the Landlord Dashboard
  static Future<Map<String, dynamic>> getMockDashboardData(
      String filter) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 600));

    final bool isWeek = filter == 'This Week';

    return {
      'overview': {
        'totalViews': isWeek ? '1,360' : '4,820',
        'growth': '+14.5%',
        'chartData': isWeek
            ? [120.0, 150.0, 180.0, 140.0, 210.0, 250.0, 310.0]
            : [
                100.0,
                120.0,
                110.0,
                160.0,
                200.0,
                180.0,
                260.0,
                290.0,
                340.0,
                310.0,
                390.0,
                420.0
              ],
      },
      'metrics': {
        'uniqueViewers': isWeek ? '942' : '2,840',
        'saves': isWeek ? '124' : '412',
        'shares': isWeek ? '38' : '115',
        'avgCtr': '5.8%',
      },
      'funnel': [
        {'label': 'Impressions', 'value': '12,400', 'percentage': 1.0},
        {'label': 'Property Views', 'value': '1,360', 'percentage': 0.11},
        {'label': 'Saves/Chats', 'value': '162', 'percentage': 0.12},
        {'label': 'Bookings', 'value': '18', 'percentage': 0.11},
      ],
      'topProperties': [
        {
          'name': 'Modern Apartment',
          'location': 'Kilimani, Nairobi',
          'image':
              'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800',
          'views': '845',
        },
        {
          'name': 'Cozy Studio',
          'location': 'Westlands, Nairobi',
          'image':
              'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800',
          'views': '532',
        },
        {
          'name': 'Luxury Villa',
          'location': 'Karen, Nairobi',
          'image':
              'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
          'views': '410',
        },
      ],
      'insight': isWeek
          ? {
              'message':
                  'Your "Modern Apartment" is getting 40% fewer views than neighbors. Boost it now to regain top ranking.',
            }
          : null,
    };
  }

  /// Fetches real-time management data for a specific property
  static Future<Map<String, dynamic>?> getPropertyManagementData(
      String propertyId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/management/$propertyId'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch property management data: $e');
    }
    return null;
  }

  /// Deletes a property from the portfolio
  static Future<bool> deleteProperty(String propertyId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  /// Updates the status of a property (Available, Rented, etc.)
  static Future<bool> updatePropertyStatus(
      String propertyId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/status'),
        body: jsonEncode({'status': status}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Handles booking accept/reject actions
  static Future<bool> updateBookingStatus(
      String bookingId, String action) async {
    try {
      // Maps "Accepted" -> confirm, "Rejected" -> cancel
      final endpoint = action == 'Accepted' ? 'confirm' : 'cancel';
      final response = await http.patch(
        Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Fetches the availability calendar for the next 14 days
  static Future<List<int>> getPropertyAvailability(String propertyId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/availability'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return List<int>.from(jsonDecode(response.body)['blocked_days']);
      }
    } catch (e) {}
    return [];
  }
}
