import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';

class BookingService {
  static String get _baseUrl => '${AppSession.apiBaseUrl}/bookings';
  static final HttpJsonClient _client = HttpJsonClient();

  static String friendlyErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('already have an active booking') ||
        message.contains('active booking') ||
        message.contains('duplicate')) {
      return 'You already have an active booking request for this property. Open My Bookings to view it.';
    }
    if (message.contains('already booked') ||
        message.contains('not available') ||
        message.contains('overlap')) {
      return 'Those dates are no longer available. Please choose different dates.';
    }
    if (message.contains('insufficient wallet balance')) {
      return 'Your wallet balance is too low. Add funds and try again.';
    }
    if (message.contains('property not found')) {
      return 'This property is no longer available.';
    }
    if (message.contains('no landlord') || message.contains('own property')) {
      return 'This property cannot accept your booking.';
    }
    return 'We could not submit your booking. Please try again.';
  }

  /// Creates a new booking request for a tenant
  static Future<Map<String, dynamic>> createBooking({
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
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Booking request failed.');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  static Future<Map<String, dynamic>> createAndPayFromWallet({
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    String? notes,
    required String idempotencyKey,
  }) async {
    String dateOnly(DateTime value) =>
        DateTime(value.year, value.month, value.day)
            .toIso8601String()
            .split('T')
            .first;

    final response = await _client.post(
      Uri.parse('$_baseUrl/pay-with-wallet'),
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'propertyId': propertyId,
        'checkInDate': dateOnly(checkIn),
        'checkOutDate': dateOnly(checkOut),
        'notes': notes,
      },
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(decoded['error']?.toString() ?? 'Payment failed.');
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
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
