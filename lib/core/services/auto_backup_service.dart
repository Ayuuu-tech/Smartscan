import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/backup_service.dart';

/// Automatic encrypted backups: once enabled with a passphrase, every vault
/// change rewrites an encrypted backup file in the app's documents folder.
/// The passphrase lives in the platform secure store (same protection as
/// the vault itself); the backup file is AES-GCM encrypted, so copying it
/// off the device without the passphrase is useless.
class AutoBackupService {
  AutoBackupService._();

  static const _passKey = 'auto_backup_pass_v1';
  static const fileName = 'smartscan_auto_backup.smbk';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<bool> isEnabled() async {
    try {
      final pass = await _storage.read(key: _passKey);
      return pass != null && pass.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enable(String passphrase) =>
      _storage.write(key: _passKey, value: passphrase);

  static Future<void> disable() async {
    await _storage.delete(key: _passKey);
    try {
      final file = await backupFile();
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static Future<File> backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Called from the vault on every persist. No-op when disabled.
  static Future<void> maybeBackup(List<WalletCard> cards) async {
    try {
      final pass = await _storage.read(key: _passKey);
      if (pass == null || pass.isEmpty) return;
      final content = await VaultBackupService.export(cards, pass);
      final file = await backupFile();
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  /// Restores the automatic backup using the stored passphrase.
  /// Returns null when no auto-backup exists.
  static Future<List<WalletCard>?> restoreLatest() async {
    final pass = await _storage.read(key: _passKey);
    if (pass == null || pass.isEmpty) return null;
    final file = await backupFile();
    if (!file.existsSync()) return null;
    return VaultBackupService.import(await file.readAsString(), pass);
  }
}
