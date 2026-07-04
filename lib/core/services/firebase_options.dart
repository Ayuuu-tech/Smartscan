import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFDi9bXf_R9Ua77_iXbmUtBQNXSylzz0s',
    appId: '1:350277273215:android:48adb0eaf279de54a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAL4UEa_l7iB2j2Hmou2LHOlVZ6ZCDWApA',
    appId: '1:350277273215:ios:4e529dcd98c8e5a2a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
    iosBundleId: 'com.scanmate.scanmate',
  );

  // macOS reuses the iOS app registration (same bundle id).
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAL4UEa_l7iB2j2Hmou2LHOlVZ6ZCDWApA',
    appId: '1:350277273215:ios:4e529dcd98c8e5a2a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
    iosBundleId: 'com.scanmate.scanmate',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCFDi9bXf_R9Ua77_iXbmUtBQNXSylzz0s',
    appId: '1:350277273215:android:48adb0eaf279de54a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
    authDomain: 'scanmate-5da65.firebaseapp.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyCFDi9bXf_R9Ua77_iXbmUtBQNXSylzz0s',
    appId: '1:350277273215:android:48adb0eaf279de54a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
    authDomain: 'scanmate-5da65.firebaseapp.com',
  );
}
