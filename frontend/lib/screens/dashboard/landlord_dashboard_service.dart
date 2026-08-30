import 'dart:convert';
import 'package:property_app/repository/http_json_client.dart';
import 'package:property_app/session/app_session.dart';

class LandlordDashboardService {
  static final HttpJsonClient _client = HttpJsonClient();
  static String get _baseUrl => '/analytics';

  static Future<Map<String, dynamic>?> getPropertyEngagementStats(String propertyId) async {
    try {
      final response = await _client.get(Uri.parse('${AppSession.apiBaseUrl}/analytics/stats/$propertyId'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch stats: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getLandlordOverview(String filter) async {
    try {
      final response = await _client.get(Uri.parse('${AppSession.apiBaseUrl}/analytics/landlord-overview?filter=${Uri.encodeComponent(filter)}'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch landlord overview: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> getMockDashboardData(String filter) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final bool isWeek = filter == 'This Week';
    return {
      'overview': {
        'totalViews': isWeek ? '1,360' : '4,820',
        'growth': '+14.5%',
        'chartData': isWeek ? [120.0, 150.0, 180.0, 140.0, 210.0, 250.0, 310.0] : [100.0, 120.0, 110.0, 160.0, 200.0, 180.0, 260.0, 290.0, 340.0, 310.0, 390.0, 420.0],
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
        {'name': 'Modern Apartment', 'location': 'Kilimani, Nairobi', 'image': 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800', 'views': '845'},
        {'name': 'Cozy Studio', 'location': 'Westlands, Nairobi', 'image': 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800', 'views': '532'},
        {'name': 'Luxury Villa', 'location': 'Karen, Nairobi', 'image': 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800', 'views': '410'},
      ],
      'insight': isWeek ? {'message': 'Your "Modern Apartment" is getting 40% fewer views than neighbors. Boost it now to regain top ranking.'} : null,
    };
  }

  static Future<Map<String, dynamic>?> getPropertyManagementData(String propertyId) async {
    try {
      final response = await _client.get(Uri.parse('${AppSession.apiBaseUrl}/analytics/management/$propertyId'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch property management data: $e');
    }
    return null;
  }

  static Future<bool> deleteProperty(String propertyId) async {
    try {
      await _client.delete(Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId'));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updatePropertyStatus(String propertyId, String status) async {
    try {
      await _client.patch(Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/status'), body: jsonEncode({'status': status}));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateBookingStatus(String bookingId, String action) async {
    try {
      final endpoint = action == 'Accepted' ? 'confirm' : 'cancel';
      await _client.patch(Uri.parse('${AppSession.apiBaseUrl}/bookings/$bookingId/$endpoint'), body: jsonEncode({}));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<int>> getPropertyAvailability(String propertyId) async {
    try {
      final response = await _client.get(Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/availability'));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        if (body['blocked_days'] != null) {
          return List<int>.from(body['blocked_days']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
