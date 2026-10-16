import 'package:flutter/widgets.dart';

/// Non-web placeholder for the Google Identity Services rendered button.
///
/// Platforms that support `GoogleSignIn.authenticate()` render their own
/// button (see `LoginView`/`RegisterView`), so this is never displayed on
/// those platforms.
Widget renderGoogleSignInButton({
  Future<void> Function()? onSignedIn,
  VoidCallback? onError,
  double? width,
}) {
  throw UnsupportedError(
    'renderGoogleSignInButton is only available on the web. On other '
    'platforms use a custom button wired to '
    'GoogleAuthService.instance.signInWithGoogle().',
  );
}