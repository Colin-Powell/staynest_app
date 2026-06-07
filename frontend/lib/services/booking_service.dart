import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

class BookingService {
  static String get _baseUrl => '${AppSession.apiBaseUrl}/bookings';

  /// Creates a new booking request for a tenant
  static Future<bool> createBooking({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalPrice,
    String? notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode({
          'propertyId': propertyId,
          'checkInDate': checkIn.toIso8601String(),
          'checkOutDate': checkOut.toIso8601String(),
          'totalPrice': totalPrice,
          'notes': notes,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Fetches bookings based on role (Tenant or Landlord)
  static Future<List<dynamic>> fetchBookings({bool isLandlord = false}) async {
    try {
      final endpoint = isLandlord ? '/landlord' : '/tenant';
      final response = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'] as List;
      }
    } catch (e) {
      print('Booking fetch error: $e');
    }
    return [];
  }

  /// Unified status updater for Accept/Reject/Cancel
  static Future<bool> updateStatus(String bookingId, String action,
      {String? reason}) async {
    try {
      // action: confirm, cancel, reject (mapped to backend routes)
      final endpoint = action.toLowerCase();
      final response = await http.patch(
        Uri.parse('$_baseUrl/$bookingId/$endpoint'),
        headers: {
          'Authorization': 'Bearer ${AppSession.apiToken}',
          'Content-Type': 'application/json',
        },
        body: reason != null ? jsonEncode({'reason': reason}) : null,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a date range is available for a specific property
  static Future<bool> checkAvailability(
      String propertyId, DateTime start, DateTime end) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${AppSession.apiBaseUrl}/properties/$propertyId/availability-check'
            '?start=${start.toIso8601String()}&end=${end.toIso8601String()}'),
        headers: {'Authorization': 'Bearer ${AppSession.apiToken}'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['available'] == true;
      }
    } catch (e) {
      print('Availability check error: $e');
    }
    return false;
  }

  /// Toggles a date's availability (for landlords)
  static Future<bool> toggleDateAvailability(
      String propertyId, DateTime date, bool isAvailable) async {
    try {
      final response = await http.post(
        Uri.parse(
            '${AppSession.apiBaseUrl}/properties/$propertyId/availability'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode(
            {'date': date.toIso8601String(), 'available': isAvailable}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
