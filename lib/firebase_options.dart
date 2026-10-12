import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD5tWzFW1ZT8DV54SLyU7DtkfiL0pqYkCw',
    appId: '1:319845589777:android:b4e690573cdf81fe01e2b0',
    messagingSenderId: '319845589777',
    projectId: 'tabangnow-mobile-2026',
    storageBucket: 'tabangnow-mobile-2026.firebasestorage.app',
  );
}