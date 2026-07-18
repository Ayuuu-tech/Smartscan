import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob configuration + init.
///
/// Ad unit ids come from --dart-define so real ids can be injected at build
/// time (see secrets.json / build_apk.sh). They DEFAULT to Google's official
/// TEST ids, which are always safe to run — never click your own live ads
/// during testing or AdMob will suspend the account.
///
/// Swap in your real ids only for the Play release build:
///   --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY
class AdsService {
  AdsService._();

  // Google's official test banner unit.
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: _testBanner,
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: _testBanner,
  );

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    }
  }

  static bool get isReady => _ready;

  static String get bannerUnitId =>
      Platform.isIOS ? _bannerIos : _bannerAndroid;

  /// True while running the built-in test unit — used to warn in-app.
  static bool get usingTestAds => bannerUnitId == _testBanner;
}
