import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';

/// Bridge to the native Android Autofill service.
///
/// Pushes a minimal, CVV-free copy of payment cards into an
/// EncryptedSharedPreferences store that `CardAutofillService` (Kotlin)
/// reads when other apps show a credit-card form. No-op on iOS —
/// Apple restricts card autofill to Safari/Keychain.
class AutofillBridge {
  AutofillBridge._();

  static const _channel = MethodChannel('smartscan/autofill');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Mirror payment cards (never CVV, never loyalty barcodes) to the
  /// native encrypted store used by the autofill service.
  static Future<void> syncCards(List<WalletCard> cards) async {
    if (!supported) return;
    try {
      final payload = json.encode([
        for (final c in cards.where(
            (c) => c.type.isPayment && c.number.isNotEmpty))
          {
            'title': c.title,
            'name': c.cardholderName,
            'number': c.number,
            'expiryMonth': c.expiryMonth,
            'expiryYear': c.expiryYear,
          },
      ]);
      await _channel.invokeMethod('syncCards', {'cards': payload});
    } catch (e) {
      debugPrint('Autofill sync failed: $e');
    }
  }

  /// Is SmartScan currently the selected system autofill service?
  static Future<bool> isServiceEnabled() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAutofillEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system dialog asking the user to set SmartScan as the
  /// autofill service.
  static Future<void> requestEnable() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('requestEnableAutofill');
    } catch (e) {
      debugPrint('Autofill enable request failed: $e');
    }
  }
}
