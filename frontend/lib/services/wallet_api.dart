import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/landlord_payment_methods_service.dart';
import 'package:uuid/uuid.dart';

class WalletApi {
  static ApiClient _client() => ApiClient(
        baseUrl: AppSession.apiBaseUrl,
        defaultHeaders: AppSession.apiToken == null
            ? null
            : {'Authorization': 'Bearer ${AppSession.apiToken!}'},
      );

  static Future<Map<String, dynamic>> getWallet() async {
    final response = await _client().getJson('/wallet');
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _client().getJson('/wallet/transactions');
    final data = response['data'] as List<dynamic>? ?? const [];
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getWithdrawals() async {
    final response = await _client().getJson('/wallet/withdrawals');
    final data = response['data'] as List<dynamic>? ?? const [];
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static Future<Map<String, dynamic>> getEscrow(String bookingId) async {
    final response = await _client().getJson('/wallet/escrow/$bookingId');
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  static Future<Map<String, dynamic>> topUp({
    required double amount,
    required LandlordPaymentMethod paymentMethod,
  }) async {
    final response = await _client().postJson('/wallet/top-up', body: {
      'amount': amount,
      'paymentMethodId': paymentMethod.id,
    });
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  static Future<Map<String, dynamic>> withdraw({
    required double amount,
    LandlordPaymentMethod? paymentMethod,
    String? newMpesaPhone,
  }) async {
    if (paymentMethod == null &&
        (newMpesaPhone == null || newMpesaPhone.isEmpty)) {
      throw ArgumentError('A payment method or new M-Pesa number is required.');
    }
    final body = <String, dynamic>{
      'amount': amount,
      if (paymentMethod?.id.isNotEmpty == true)
        'paymentMethodId': paymentMethod!.id,
      if (newMpesaPhone != null && newMpesaPhone.trim().isNotEmpty)
        'newMpesaPhone': newMpesaPhone.trim(),
      'idempotencyKey': const Uuid().v4(),
    };
    final response = await _client().postJson('/wallet/withdraw', body: body);
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  static Future<Map<String, dynamic>> payBooking(String bookingId) async {
    final response = await _client().postJson('/wallet/pay-booking', body: {
      'bookingId': bookingId,
      'idempotencyKey': const Uuid().v4(),
    });
    return Map<String, dynamic>.from(response['data'] as Map);
  }
}
