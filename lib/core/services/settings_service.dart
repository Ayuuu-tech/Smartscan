import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide user settings persisted to a small JSON file on device.
/// (Card data itself lives in the encrypted vault, not here.)
class AppSettings {
  /// Require biometric/PIN unlock when opening the wallet.
  final bool appLock;

  /// Allow storing CVV in the vault (off by default — safer).
  final bool storeCvv;

  /// User chose "continue without account" — skip the login flow.
  final bool guestMode;

  const AppSettings({
    this.appLock = true,
    this.storeCvv = false,
    this.guestMode = false,
  });

  AppSettings copyWith({bool? appLock, bool? storeCvv, bool? guestMode}) =>
      AppSettings(
        appLock: appLock ?? this.appLock,
        storeCvv: storeCvv ?? this.storeCvv,
        guestMode: guestMode ?? this.guestMode,
      );

  Map<String, dynamic> toMap() => {
        'appLock': appLock,
        'storeCvv': storeCvv,
        'guestMode': guestMode,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        appLock: map['appLock'] as bool? ?? true,
        storeCvv: map['storeCvv'] as bool? ?? false,
        guestMode: map['guestMode'] as bool? ?? false,
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => _load();

  Future<void> setAppLock(bool value) async {
    final updated =
        (state.value ?? const AppSettings()).copyWith(appLock: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setGuestMode(bool value) async {
    final updated =
        (state.value ?? const AppSettings()).copyWith(guestMode: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setStoreCvv(bool value) async {
    final updated =
        (state.value ?? const AppSettings()).copyWith(storeCvv: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/smartscan_settings.json');
  }

  static Future<AppSettings> _load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return const AppSettings();
      final raw = await file.readAsString();
      return AppSettings.fromMap(json.decode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SettingsNotifier load error: $e');
      return const AppSettings();
    }
  }

  static Future<void> _save(AppSettings settings) async {
    try {
      final file = await _file();
      await file.writeAsString(json.encode(settings.toMap()));
    } catch (e) {
      debugPrint('SettingsNotifier save error: $e');
    }
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
