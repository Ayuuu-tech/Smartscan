import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Email OTP via Resend (resend.com).
///
/// The code is generated on-device, emailed through the Resend API, and
/// only its SHA-256 hash is kept in memory while it's pending.
///
/// ⚠️ The API key ships inside the APK, so it can be extracted. For a
/// public launch, move the send-OTP call behind your own backend and keep
/// the key there.
class OtpService {
  // ----------------------------------------------------------------
  // CONFIG — fill these in:
  //  * apiKey: Resend dashboard → API Keys (starts with "re_").
  //  * from:   must be on a domain you verified in Resend. Until you
  //    verify one, "onboarding@resend.dev" works but only delivers to
  //    the email address that owns the Resend account.
  // ----------------------------------------------------------------
  static const String _apiKey = String.fromEnvironment(
    'RESEND_API_KEY',
    defaultValue: 'PASTE_RESEND_API_KEY_HERE',
  );
  static const String _from = String.fromEnvironment(
    'RESEND_FROM',
    defaultValue: 'SmartScan <onboarding@resend.dev>',
  );

  static const _codeLifetime = Duration(minutes: 10);
  static const _maxAttempts = 5;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? _pendingHash;
  static String? _pendingEmail;
  static DateTime? _expiresAt;
  static int _attemptsLeft = 0;

  static bool get isConfigured => _apiKey.startsWith('re_');

  /// True when a code has been sent and is still valid for this email.
  static bool hasPendingFor(String email) =>
      _pendingHash != null &&
      _pendingEmail == email.toLowerCase() &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  /// Generates a 6-digit code and emails it. Returns null on success,
  /// otherwise a user-facing error message.
  static Future<String?> sendOtp(String email) async {
    if (!isConfigured) {
      return 'OTP service not configured yet. Please contact support.';
    }
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    try {
      final res = await http
          .post(
            Uri.parse('https://api.resend.com/emails'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'from': _from,
              'to': [email],
              'subject': 'Your SmartScan verification code: $code',
              'html': '''
                <div style="font-family:sans-serif;max-width:420px;margin:auto">
                  <h2 style="color:#E36A26">SmartScan</h2>
                  <p>Your verification code is:</p>
                  <p style="font-size:32px;font-weight:bold;letter-spacing:8px">$code</p>
                  <p style="color:#888">It expires in 10 minutes. If you didn't request this, ignore this email.</p>
                </div>''',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // Surface Resend's own reason (e.g. test-mode recipient limit).
        try {
          final msg = json.decode(res.body)['message'];
          if (msg is String && msg.isNotEmpty) return msg;
        } catch (_) {}
        return 'Could not send the code (${res.statusCode}). Try again.';
      }
      _pendingHash = sha256.convert(utf8.encode(code)).toString();
      _pendingEmail = email.toLowerCase();
      _expiresAt = DateTime.now().add(_codeLifetime);
      _attemptsLeft = _maxAttempts;
      return null;
    } catch (_) {
      return 'Could not send the code. Check your internet connection.';
    }
  }

  /// Returns null when the code is correct, otherwise an error message.
  static String? verify(String email, String code) {
    if (_pendingHash == null || _pendingEmail != email.toLowerCase()) {
      return 'No code pending. Tap "Resend code" first.';
    }
    if (DateTime.now().isAfter(_expiresAt!)) {
      _clear();
      return 'Code expired. Tap "Resend code" for a new one.';
    }
    if (_attemptsLeft <= 0) {
      _clear();
      return 'Too many wrong attempts. Request a new code.';
    }
    if (sha256.convert(utf8.encode(code.trim())).toString() != _pendingHash) {
      _attemptsLeft--;
      return 'Incorrect code. $_attemptsLeft attempts left.';
    }
    _clear();
    return null;
  }

  static void _clear() {
    _pendingHash = null;
    _pendingEmail = null;
    _expiresAt = null;
    _attemptsLeft = 0;
  }

  // ----------------------------------------------------------------
  // Per-device "this account passed OTP" flag, so users only verify
  // once per device — the standard OTP-on-new-device behavior.
  // ----------------------------------------------------------------
  static Future<bool> isDeviceVerified(String uid) async =>
      await _storage.read(key: 'otp_verified_$uid') == '1';

  static Future<void> markDeviceVerified(String uid) =>
      _storage.write(key: 'otp_verified_$uid', value: '1');
}
