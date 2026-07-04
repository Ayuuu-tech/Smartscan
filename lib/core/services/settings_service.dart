import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App-wide user settings persisted to a small JSON file on device.
class AppSettings {
  final bool cloudBackup;
  final bool autoCapture;
  final String defaultFilter; // matches ScanFilterType names, e.g. 'magicColor'
  final String imageQuality; // 'High' | 'Medium' | 'Low'

  const AppSettings({
    this.cloudBackup = true,
    this.autoCapture = true,
    this.defaultFilter = 'magicColor',
    this.imageQuality = 'High',
  });

  /// JPEG quality (0–100) derived from the [imageQuality] label.
  int get jpegQuality {
    switch (imageQuality) {
      case 'Low':
        return 60;
      case 'Medium':
        return 80;
      case 'High':
      default:
        return 92;
    }
  }

  AppSettings copyWith({
    bool? cloudBackup,
    bool? autoCapture,
    String? defaultFilter,
    String? imageQuality,
  }) =>
      AppSettings(
        cloudBackup: cloudBackup ?? this.cloudBackup,
        autoCapture: autoCapture ?? this.autoCapture,
        defaultFilter: defaultFilter ?? this.defaultFilter,
        imageQuality: imageQuality ?? this.imageQuality,
      );

  Map<String, dynamic> toMap() => {
        'cloudBackup': cloudBackup,
        'autoCapture': autoCapture,
        'defaultFilter': defaultFilter,
        'imageQuality': imageQuality,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
        cloudBackup: map['cloudBackup'] as bool? ?? true,
        autoCapture: map['autoCapture'] as bool? ?? true,
        defaultFilter: map['defaultFilter'] as String? ?? 'magicColor',
        imageQuality: map['imageQuality'] as String? ?? 'High',
      );
}

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => _load();

  Future<void> setCloudBackup(bool value) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(cloudBackup: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setAutoCapture(bool value) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(autoCapture: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setDefaultFilter(String value) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(defaultFilter: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> setImageQuality(String value) async {
    final current = state.value ?? const AppSettings();
    final updated = current.copyWith(imageQuality: value);
    state = AsyncData(updated);
    await _save(updated);
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/scanmate_settings.json');
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
