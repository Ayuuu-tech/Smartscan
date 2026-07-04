import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:scanmate/core/services/firebase_options.dart';

class FirebaseService {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully.');
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  }
}
