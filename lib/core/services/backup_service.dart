import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';

/// Passphrase-encrypted vault backup.
///
/// Format (JSON): { v, kdf: {salt, iterations}, nonce, cipherText, mac }.
/// Key = PBKDF2-HMAC-SHA256(passphrase), cipher = AES-256-GCM. The backup
/// file is useless without the passphrase, so it's safe to keep in Drive,
/// email — anywhere.
class VaultBackupService {
  VaultBackupService._();

  static const int _iterations = 150000;
  static final AesGcm _cipher = AesGcm.with256bits();

  static Future<SecretKey> _deriveKey(
      String passphrase, List<int> salt) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  /// Encrypts [cards] with [passphrase]; returns the backup file content.
  static Future<String> export(
      List<WalletCard> cards, String passphrase) async {
    final salt = _cipher.newNonce(); // random 12 bytes is fine as KDF salt
    final key = await _deriveKey(passphrase, salt);
    final clearText = utf8.encode(WalletCard.encodeList(cards));
    final box = await _cipher.encrypt(clearText, secretKey: key);
    return json.encode({
      'v': 1,
      'app': 'smartscan_cards',
      'kdf': {'salt': base64Encode(salt), 'iterations': _iterations},
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Decrypts backup [content]. Throws [BackupException] on a wrong
  /// passphrase or malformed file.
  static Future<List<WalletCard>> import(
      String content, String passphrase) async {
    final Map<String, dynamic> data;
    try {
      data = json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('Not a valid backup file.');
    }
    if ((data['app'] != 'smartscan_cards' && data['app'] != 'scanmate_cards') ||
        data['v'] != 1) {
      throw const BackupException('Not a valid backup file.');
    }
    try {
      final salt = base64Decode((data['kdf'] as Map)['salt'] as String);
      final key = await _deriveKey(passphrase, salt);
      final box = SecretBox(
        base64Decode(data['cipherText'] as String),
        nonce: base64Decode(data['nonce'] as String),
        mac: Mac(base64Decode(data['mac'] as String)),
      );
      final clear = await _cipher.decrypt(box, secretKey: key);
      return WalletCard.decodeList(utf8.decode(clear));
    } on SecretBoxAuthenticationError {
      throw const BackupException('Wrong passphrase.');
    } catch (_) {
      throw const BackupException('Could not read this backup.');
    }
  }
}

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}
