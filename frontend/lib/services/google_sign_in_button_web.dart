import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

import 'package:property_app/services/google_auth_service.dart';

/// Renders the Google Identity Services sign-in button — the only supported
/// way to start a Google sign-in on the web (custom UI calling `authenticate`
/// is rejected by the GIS SDK).
///
/// When the user completes the GIS flow, the plugin emits a sign-in event on
/// [GoogleAuthService.authenticationEvents]; [onSignedIn] is then invoked so
/// the caller can run the exact same post-authentication flow used on other
/// platforms (which exchanges the ID token via
/// `GoogleAuthService.signInWithGoogle`).
///
/// [onError] is invoked when the sign-in flow itself fails.
Widget renderGoogleSignInButton({
  Future<void> Function()? onSignedIn,
  VoidCallback? onError,
  double? width,
}) {
  return _GoogleSignInWebButton(
    onSignedIn: onSignedIn,
    onError: onError,
    width: width,
  );
}

class _GoogleSignInWebButton extends StatefulWidget {
  const _GoogleSignInWebButton({
    required this.onSignedIn,
    required this.onError,
    required this.width,
  });

  final Future<void> Function()? onSignedIn;
  final VoidCallback? onError;
  final double? width;

  @override
  State<_GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<_GoogleSignInWebButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _handlingEvent = false;

  @override
  void initState() {
    super.initState();
    // The GIS button can only be clicked after the plugin is initialized.
    unawaited(GoogleAuthService.instance.initialize());
    _subscription =
        GoogleAuthService.instance.authenticationEvents.listen(_handleEvent);
  }

  void _handleEvent(GoogleSignInAuthenticationEvent event) {
    if (_handlingEvent || event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }
    final callback = widget.onSignedIn;
    if (callback == null) return;

    _handlingEvent = true;
    callback().catchError((Object error) {
      debugPrint('[GoogleSignIn] web sign-in flow failed: $error');
      widget.onError?.call();
    }).whenComplete(() {
      _handlingEvent = false;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.outline,
          text: web.GSIButtonText.continueWith,
          size: web.GSIButtonSize.large,
        ),
      ),
    );
  }
}