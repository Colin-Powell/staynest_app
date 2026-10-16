import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;
import 'package:web/web.dart' as browser;

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
  /// The GIS SDK script has no load timeout of its own; if it is blocked by
  /// the network or an extension, plugin init would otherwise never complete
  /// and the button would wait forever.
  static const _initTimeout = Duration(seconds: 12);

  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  late final Future<void> _initFuture;
  bool _handlingEvent = false;

  @override
  void initState() {
    super.initState();
    // The GIS button can only be clicked after the plugin is initialized;
    // the FutureBuilder below renders a placeholder until then and surfaces
    // initialization errors instead of hanging forever.
    _initFuture =
        GoogleAuthService.instance.initialize().timeout(_initTimeout);
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
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.hasError) {
            debugPrint('[GoogleSignIn] init failed: ${snapshot.error}');
            return _InitFailedView(
              onRefresh: () => browser.window.location.reload(),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return web.renderButton(
            configuration: web.GSIButtonConfiguration(
              type: web.GSIButtonType.standard,
              theme: web.GSIButtonTheme.outline,
              text: web.GSIButtonText.continueWith,
              size: web.GSIButtonSize.large,
            ),
          );
        },
      ),
    );
  }
}

/// Shown when the Google Identity Services SDK failed to initialize (e.g. the
/// GIS script is blocked by the network or a browser extension). The plugin's
/// init cannot be retried within the same session, so the only recovery is a
/// full page reload.
class _InitFailedView extends StatelessWidget {
  const _InitFailedView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Google Sign-In could not load. It may be blocked by your browser '
          'or network.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRefresh,
          child: const Text('Refresh the page'),
        ),
      ],
    );
  }
}