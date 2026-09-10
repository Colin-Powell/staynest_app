import 'package:property_app/services/api_client.dart';
import 'package:property_app/session/app_session.dart';

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
}
