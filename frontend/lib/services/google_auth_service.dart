import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:property_app/session/app_session.dart';

class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<bool> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return false;
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) return false;

    // Send idToken to backend for verification and JWT issuance
    final response = await http.post(
        Uri.parse('${AppSession.apiBaseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final data = body['data'];
      AppSession.apiToken = data['token'];
      AppSession.updateCurrentUser(data['user']);
      return true;
    }

    return false;
  }
}
