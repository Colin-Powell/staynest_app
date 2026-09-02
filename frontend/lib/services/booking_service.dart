import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';

class BookingService {
  static String get _baseUrl => '${AppSession.apiBaseUrl}/bookings';
  static final HttpJsonClient _client = HttpJsonClient();

  /// Creates a new booking request for a tenant
  static Future<bool> createBooking({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalPrice,
    String? notes,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Uri.parse(_baseUrl),
      headers: {
        'Idempotency-Key': idempotencyKey,
      },
      body: {
        'propertyId': propertyId,
        'checkInDate': checkIn.toIso8601String(),
        'checkOutDate': checkOut.toIso8601String(),
        'totalPrice': totalPrice,
        'notes': notes,
      },
    );
    return response.statusCode == 201 || response.statusCode == 200;
  }

  /// Fetches bookings based on role (Tenant or Landlord)
  static Future<List<dynamic>> fetchBookings({bool isLandlord = false}) async {
    final endpoint = isLandlord ? '/landlord' : '/tenant';
    final response = await _client.get(Uri.parse('$_baseUrl$endpoint'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] as List;
    }
    return [];
  }

  /// Unified status updater for Accept/Reject/Cancel
  static Future<bool> updateStatus(String bookingId, String action,
      {String? reason}) async {
    final endpoint = action.toLowerCase();
    final response = await _client.patch(
      Uri.parse('$_baseUrl/$bookingId/$endpoint'),
      body: reason != null ? {'reason': reason} : null,
    );
    return response.statusCode == 200;
  }

  /// Checks if a date range is available for a specific property
  static Future<bool> checkAvailability(
      String propertyId, DateTime start, DateTime end) async {
    final response = await _client.get(
      Uri.parse(
          '${AppSession.apiBaseUrl}/properties/$propertyId/availability-check'
          '?start=${start.toIso8601String()}&end=${end.toIso8601String()}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['available'] == true;
    }
    return false;
  }

  /// Toggles a date's availability (for landlords)
  static Future<bool> toggleDateAvailability(
      String propertyId, DateTime date, bool isAvailable) async {
    final response = await _client.post(
      Uri.parse('${AppSession.apiBaseUrl}/properties/$propertyId/availability'),
      body: {'date': date.toIso8601String(), 'available': isAvailable},
    );
    return response.statusCode == 200;
  }
}
