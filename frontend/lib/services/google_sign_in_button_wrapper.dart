// Conditional import so non-web builds never pull in google_sign_in_web.
export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';