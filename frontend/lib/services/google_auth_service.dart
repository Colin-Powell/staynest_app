import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:property_app/services/analytics/analytics_service.dart';
import 'package:property_app/session/app_session.dart';

/// Google Sign-In backed by google_sign_in 7.x (Google Identity Services).
///
/// Platform notes:
/// * Android/iOS/macOS report `supportsAuthenticate() == true` and start the
///   flow from the app's own button via [GoogleSignIn.authenticate].
/// * Web does NOT allow custom UI to start sign-in; the Google SDK only
///   accepts the button it renders itself. On web, render the widget from
///   `renderGoogleSignInButton` (see `google_sign_in_button_wrapper.dart`)
///   and keep calling [signInWithGoogle] afterwards — it resolves the ID token
///   produced by the rendered button via the authentication event stream.
class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();
  GoogleAuthService._();

  static const _webClientId =
      '193200636263-vsbg83ntukhk0vcj8fkgtvfll3b4chk6.apps.googleusercontent.com';
  // On Android/iOS, serverClientId must match the Firebase OAuth Web Client ID (from google-services.json)
  static const _firebaseWebClientId =
      '193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com';
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: _firebaseWebClientId,
  );

  final GoogleSignIn _signIn = GoogleSignIn.instance;

  Future<void>? _initializing;
  GoogleSignInAccount? _pendingWebAccount;

  /// Re-export of the platform authentication event stream. Sign-in events
  /// fired by the web `renderButton()` widget surface here.
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _signIn.authenticationEvents;

  /// Initializes the [GoogleSignIn] singleton exactly once. Safe to call
  /// multiple times.
  Future<void> initialize() {
    return _initializing ??= () async {
      debugPrint('[GoogleSignIn] init start (kIsWeb=$kIsWeb)');
      // Subscribe before initializing so no event is missed.
      _signIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: (Object error) =>
            debugPrint('[GoogleSignIn] authentication error: $error'),
      );
      // IMPORTANT: the web plugin asserts `serverClientId == null`
      // ("serverClientId is not supported on Web"). Passing it makes the
      // plugin's init() throw in debug builds *before* it completes its
      // internal ready future, which leaves renderButton() stuck on its
      // "Getting ready" placeholder forever. Only pass it on native platforms,
      // where it is needed to mint ID tokens for the backend's OAuth client.
      await _signIn.initialize(
        clientId: kIsWeb ? _webClientId : null,
        serverClientId: kIsWeb ? null : _serverClientId,
      );
      debugPrint('[GoogleSignIn] init complete');
    }();
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      // Remember the account so the explicit sign-in request that follows a
      // web button click can exchange the ID token without waiting for
      // another event.
      _pendingWebAccount = event.user;
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      _pendingWebAccount = null;
    }
  }

  /// Completes an interactive Google sign-in and exchanges the resulting ID
  /// token for a StayNest session.
  ///
  /// Returns `true` on success and `false` when the user cancels the flow.
  Future<bool> signInWithGoogle({String? role}) async {
    await initialize();

    try {
      final GoogleSignInAccount account;
      if (_signIn.supportsAuthenticate()) {
        account = await _signIn.authenticate();
      } else {
        // Web: the account was already produced by the SDK-rendered button
        // (renderButton) via authenticationEvents.
        account = await _resolveWebAccount();
      }
      return await _exchangeIdToken(account, role: role);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;
      debugPrint(
          '[GoogleSignIn] sign-in failed: ${error.code} ${error.description}');
      rethrow;
    }
  }

  Future<GoogleSignInAccount> _resolveWebAccount() {
    final pending = _pendingWebAccount;
    if (pending != null) {
      _pendingWebAccount = null;
      return Future.value(pending);
    }

    // No pending button event yet. Wait for the next sign-in event so all
    // callers keep a single code path.
    final completer = Completer<GoogleSignInAccount>();
    late final StreamSubscription<GoogleSignInAuthenticationEvent> subscription;
    subscription = _signIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn &&
            !completer.isCompleted) {
          completer.complete(event.user);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
      cancelOnError: true,
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(StateError(
              'Google Sign-In stream closed before sign-in completed.'));
        }
      },
    );
    return completer.future.whenComplete(subscription.cancel);
  }

  Future<bool> _exchangeIdToken(
    GoogleSignInAccount account, {
    String? role,
  }) async {
    final idToken = account.authentication.idToken;
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

  /// Signs the user out of Google and clears any pending sign-in state.
  Future<void> signOut() async {
    await initialize();
    _pendingWebAccount = null;
    await _signIn.signOut();
  }
}
