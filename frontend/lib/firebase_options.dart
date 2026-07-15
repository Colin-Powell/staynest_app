import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyDHC6sT1nMwwvt7MAnWmi1yx8iQaVTqMMk',
        appId: '1:193200636263:web:be474b649bb8053a02efc2',
        messagingSenderId: '193200636263',
        projectId: 'staynest-3a1bb',
        authDomain: 'staynest-3a1bb.firebaseapp.com',
        storageBucket: 'staynest-3a1bb.firebasestorage.app',
        measurementId: 'G-NTE11150WY',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDHC6sT1nMwwvt7MAnWmi1yx8iQaVTqMMk',
          appId: '1:193200636263:android:be474b649bb8053a02efc2',
          messagingSenderId: '193200636263',
          projectId: 'staynest-3a1bb',
          storageBucket: 'staynest-3a1bb.firebasestorage.app',
        );
      case TargetPlatform.iOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDHC6sT1nMwwvt7MAnWmi1yx8iQaVTqMMk',
          appId: '1:193200636263:ios:be474b649bb8053a02efc2',
          messagingSenderId: '193200636263',
          projectId: 'staynest-3a1bb',
          storageBucket: 'staynest-3a1bb.firebasestorage.app',
          iosBundleId: 'com.example.propertyapp',
        );
      case TargetPlatform.macOS:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDHC6sT1nMwwvt7MAnWmi1yx8iQaVTqMMk',
          appId: '1:193200636263:macos:be474b649bb8053a02efc2',
          messagingSenderId: '193200636263',
          projectId: 'staynest-3a1bb',
          storageBucket: 'staynest-3a1bb.firebasestorage.app',
          iosBundleId: 'com.example.propertyapp',
        );
      default:
        return const FirebaseOptions(
          apiKey: 'AIzaSyDHC6sT1nMwwvt7MAnWmi1yx8iQaVTqMMk',
          appId: '1:193200636263:web:be474b649bb8053a02efc2',
          messagingSenderId: '193200636263',
          projectId: 'staynest-3a1bb',
          authDomain: 'staynest-3a1bb.firebaseapp.com',
          storageBucket: 'staynest-3a1bb.firebasestorage.app',
          measurementId: 'G-NTE11150WY',
        );
    }
  }
}
