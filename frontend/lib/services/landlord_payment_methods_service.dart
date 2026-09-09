import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

class LandlordPaymentMethod {
  final String id;
  final String type; // mpesa | bank_transfer | card
  final String displayName;
  final String accountNumber; // phone or account number
  final String bankName; // for bank transfers
  final bool isDefault;
  final String lastUsed; // timestamp
  final String createdAt;

  LandlordPaymentMethod({
    required this.id,
    required this.type,
    required this.displayName,
    required this.accountNumber,
    this.bankName = '',
    required this.isDefault,
    required this.lastUsed,
    required this.createdAt,
  });

  factory LandlordPaymentMethod.fromJson(Map<String, dynamic> json) {
    return LandlordPaymentMethod(
      id: json['id'] ?? '',
      type: json['type'] ?? 'mpesa',
      displayName: json['display_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      bankName: json['bank_name'] ?? '',
      isDefault: json['is_default'] ?? false,
      lastUsed: json['last_used'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'display_name': displayName,
        'account_number': accountNumber,
        'bank_name': bankName,
        'is_default': isDefault,
        'last_used': lastUsed,
        'created_at': createdAt,
      };

  String get maskedAccount {
    if (accountNumber.length < 4) return accountNumber;
    return '*' * (accountNumber.length - 4) +
        accountNumber.substring(accountNumber.length - 4);
  }

  String get typeLabel {
    switch (type) {
      case 'mpesa':
        return 'M-Pesa';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
        return 'Card';
      default:
        return type;
    }
  }
}

class LandlordPaymentMethodsService {
  static String normalizeMpesaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('254')) return digits;
    if (digits.startsWith('0')) return '254${digits.substring(1)}';
    return '254$digits';
  }

  static bool isValidMpesaPhone(String value) {
    final normalized = normalizeMpesaPhone(value);
    return RegExp(r'^254[17]\d{8}$').hasMatch(normalized);
  }

  static ApiClient _client() => ApiClient(
        baseUrl: AppSession.apiBaseUrl,
        defaultHeaders: AppSession.apiToken != null
            ? {'Authorization': 'Bearer ${AppSession.apiToken!}'}
            : null,
      );

  /// Get all payment methods for landlord
  static Future<List<LandlordPaymentMethod>> getPaymentMethods() async {
    try {
      final client = _client();
      final response = await client.getJson('/landlord/payment-methods');
      final data = response['data'] as List<dynamic>? ?? [];
      return data
          .map((m) => LandlordPaymentMethod.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      landlordPaymentMethodsDebugPrint('Error fetching payment methods: $e');
      return [];
    }
  }

  /// Get default payment method
  static Future<LandlordPaymentMethod?> getDefaultMethod() async {
    try {
      final methods = await getPaymentMethods();
      for (final method in methods) {
        if (method.isDefault) return method;
      }
      return methods.isNotEmpty ? methods.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Add M-Pesa payment method
  static Future<LandlordPaymentMethod> addMpesaMethod({
    required String phone,
    required bool isDefault,
  }) async {
    if (!isValidMpesaPhone(phone)) {
      throw const FormatException('Enter a valid Kenyan M-Pesa number.');
    }

    try {
      final client = _client();
      final normalizedPhone = normalizeMpesaPhone(phone);
      final response =
          await client.postJson('/landlord/payment-methods', body: {
        'type': 'mpesa',
        'account_number': normalizedPhone,
        'display_name':
            'M-Pesa - ${normalizedPhone.substring(normalizedPhone.length - 4)}',
        'is_default': isDefault,
      });
      return LandlordPaymentMethod.fromJson(
          response['data'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Add bank transfer payment method
  static Future<LandlordPaymentMethod> addBankMethod({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
    required bool isDefault,
  }) async {
    try {
      final client = _client();
      final response =
          await client.postJson('/landlord/payment-methods', body: {
        'type': 'bank_transfer',
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder': accountHolder,
        'display_name':
            '$bankName - ${accountNumber.substring(accountNumber.length - 4)}',
        'is_default': isDefault,
      });
      return LandlordPaymentMethod.fromJson(
          response['data'] as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Set as default payment method
  static Future<void> setDefault(String methodId) async {
    try {
      final client = _client();
      await client.postJson('/landlord/payment-methods/$methodId/set-default');
    } catch (e) {
      rethrow;
    }
  }

  /// Delete payment method
  static Future<void> deleteMethod(String methodId) async {
    try {
      final client = _client();
      await client.deleteJson('/landlord/payment-methods/$methodId');
    } catch (e) {
      rethrow;
    }
  }
}

void landlordPaymentMethodsDebugPrint(String message) {
  print(message);
}
