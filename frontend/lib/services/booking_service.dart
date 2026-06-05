import 'package:property_app/services/api_client.dart';

class BookingService {
  final ApiClient apiClient;

  BookingService(this.apiClient);

  // Create a new booking (tenant)
  Future<Map<String, dynamic>> createBooking({
    required String propertyId,
    required String checkInDate,
    required String checkOutDate,
    required double totalPrice,
    String? notes,
  }) async {
    final response = await apiClient.postJson(
      '/bookings',
      body: {
        'propertyId': propertyId,
        'checkInDate': checkInDate,
        'checkOutDate': checkOutDate,
        'totalPrice': totalPrice,
        if (notes != null) 'notes': notes,
      },
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  // Get tenant's bookings
  Future<List<Map<String, dynamic>>> getTenantBookings() async {
    final response = await apiClient.getJson('/bookings/tenant');
    return _extractList(response);
  }

  // Get landlord's bookings
  Future<List<Map<String, dynamic>>> getLandlordBookings() async {
    final response = await apiClient.getJson('/bookings/landlord');
    return _extractList(response);
  }

  // Confirm booking (landlord)
  Future<Map<String, dynamic>> confirmBooking(String bookingId) async {
    final response = await apiClient.patchJson(
      '/bookings/$bookingId/confirm',
      body: {},
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  // Cancel booking
  Future<Map<String, dynamic>> cancelBooking(String bookingId,
      {String? reason}) async {
    final response = await apiClient.patchJson(
      '/bookings/$bookingId/cancel',
      body: {
        if (reason != null) 'reason': reason,
      },
    );
    return response['data'] is Map<String, dynamic>
        ? response['data']
        : <String, dynamic>{};
  }

  // Get booking details
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    final response = await apiClient.getJson('/bookings/$bookingId');
    return response['data'] is Map<String, dynamic> ? response['data'] : null;
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is Map<String, dynamic> && payload['data'] is List) {
      return List<Map<String, dynamic>>.from(payload['data'] as List);
    }
    return [];
  }
}
