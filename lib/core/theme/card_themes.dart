import 'package:flutter/material.dart';

/// A two-tone gradient theme applied to wallet cards and the user's own
/// visiting card.
class WalletCardTheme {
  final String name;
  final int color1;
  final int color2;

  const WalletCardTheme(this.name, this.color1, this.color2);

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(color1), Color(color2)],
      );

  /// All selectable themes. Index is persisted (visiting card), so only
  /// append — never reorder or remove.
  static const List<WalletCardTheme> presets = [
    WalletCardTheme('Midnight', 0xFF1F2A44, 0xFF0F1626),
    WalletCardTheme('Sunset', 0xFFE36A26, 0xFF7B241C),
    WalletCardTheme('Ocean', 0xFF117A65, 0xFF0B4F44),
    WalletCardTheme('Royal', 0xFF5B2C6F, 0xFF2E1437),
    WalletCardTheme('Gold', 0xFFB9770E, 0xFF7D4E04),
    WalletCardTheme('Rose', 0xFFC2185B, 0xFF6A0F32),
    WalletCardTheme('Slate', 0xFF34495E, 0xFF1B2631),
    WalletCardTheme('Forest', 0xFF196F3D, 0xFF0B3B1F),
    WalletCardTheme('Onyx', 0xFF212121, 0xFF000000),
    WalletCardTheme('Sky', 0xFF2E5CB8, 0xFF16305F),
  ];

  static WalletCardTheme byIndex(int index) =>
      presets[index.clamp(0, presets.length - 1)];
}
