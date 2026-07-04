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

  // WARNING: appId below is the ANDROID app id (…:android:…). iOS must use its
  // own iOS-registered app id. Register the iOS app in the Firebase console and
  // regenerate this file via `flutterfire configure` before shipping to iOS.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCFDi9bXf_R9Ua77_iXbmUtBQNXSylzz0s',
    appId: '1:350277273215:android:48adb0eaf279de54a1e14a',
    messagingSenderId: '350277273215',
    projectId: 'scanmate-5da65',
    storageBucket: 'scanmate-5da65.firebasestorage.app',
    iosBundleId: 'com.scanmate.scanmate',
  );

  // WARNING: reuses the Android app id — register macOS/Windows/Linux apps in
  // Firebase and run `flutterfire configure` to get correct per-platform ids.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCFDi9bXf_R9Ua77_iXbmUtBQNXSylzz0s',
    appId: '1:350277273215:android:48adb0eaf279de54a1e14a',
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
