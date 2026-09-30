import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/services/analytics/analytics_service.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  static const _webClientId =
      '193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com';
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: _webClientId,
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: _serverClientId,
  );

  Future<bool> signInWithGoogle({String? role}) async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
          'Google did not return an ID token. Check the OAuth client configuration.');
    }

    // Send idToken to backend for verification and JWT issuance
    final response = await http.post(
        Uri.parse('${AppSession.apiBaseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken, if (role != null) 'role': role}));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'];
      AppSession.apiToken =
          data['token']?.toString() ?? data['accessToken']?.toString();
      AnalyticsService.logAuthEvent(AnalyticsEvents.login, method: 'google');
      AppSession.refreshToken = data['refreshToken']?.toString();
      AppSession.updateCurrentUser(data['user']);
      await AppSession.persistSession();
      return true;
    }

    final body = jsonDecode(response.body);
    throw StateError(
      body is Map && body['error'] != null
          ? body['error'].toString()
          : 'Google authentication was rejected by the server.',
    );
  }
}
