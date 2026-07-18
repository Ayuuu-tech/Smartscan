import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/core/services/auto_backup_service.dart';
import 'package:smartscan/core/services/autofill_bridge.dart';
import 'package:smartscan/core/services/notification_service.dart';

/// Encrypted card vault.
///
/// All cards are stored as a single JSON blob in the platform secure store
/// (Android Keystore-backed EncryptedSharedPreferences / iOS Keychain).
/// Nothing here ever touches the network or Firebase.
class CardVaultNotifier extends AsyncNotifier<List<WalletCard>> {
  static const _legacyStorageKey = 'wallet_cards_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Storage key scoped to the signed-in account, so each account only
  /// ever sees its own cards.
  late String _storageKey;

  @override
  Future<List<WalletCard>> build() async {
    // Rebuilds automatically on login/logout/account switch.
    final uid = ref.watch(authStateProvider)?.uid;
    _storageKey = uid == null ? _legacyStorageKey : 'wallet_cards_v1_$uid';
    try {
      var raw = await _storage.read(key: _storageKey);
      // One-time migration: cards saved before per-account scoping live
      // under the legacy key — hand them to the first account that loads.
      if ((raw == null || raw.isEmpty) && uid != null) {
        final legacy = await _storage.read(key: _legacyStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          await _storage.write(key: _storageKey, value: legacy);
          await _storage.delete(key: _legacyStorageKey);
          raw = legacy;
        }
      }
      final cards =
          (raw == null || raw.isEmpty) ? <WalletCard>[] : WalletCard.decodeList(raw);
      // Keep the Android Autofill dataset in sync with the active account.
      await AutofillBridge.syncCards(cards);
      return cards;
    } catch (e) {
      debugPrint('CardVault load error: $e');
      return [];
    }
  }

  Future<void> addCard(WalletCard card) async {
    final cards = [...state.value ?? <WalletCard>[], card];
    await _persist(cards);
  }

  Future<void> updateCard(WalletCard card) async {
    final cards = [
      for (final c in state.value ?? <WalletCard>[])
        if (c.id == card.id) card else c,
    ];
    await _persist(cards);
  }

  Future<void> deleteCard(String id) async {
    final cards =
        (state.value ?? <WalletCard>[]).where((c) => c.id != id).toList();
    await _persist(cards);
  }

  Future<void> toggleFavorite(String id) async {
    final cards = [
      for (final c in state.value ?? <WalletCard>[])
        if (c.id == id) c.copyWith(isFavorite: !c.isFavorite) else c,
    ];
    await _persist(cards);
  }

  /// Merge restored/shared cards into the vault; existing ids win.
  /// Returns how many cards were actually added.
  Future<int> importCards(List<WalletCard> imported) async {
    final existing = state.value ?? <WalletCard>[];
    final existingIds = existing.map((c) => c.id).toSet();
    final fresh =
        imported.where((c) => !existingIds.contains(c.id)).toList();
    if (fresh.isNotEmpty) {
      await _persist([...existing, ...fresh]);
    }
    return fresh.length;
  }

  Future<void> _persist(List<WalletCard> cards) async {
    state = AsyncData(cards);
    await _storage.write(key: _storageKey, value: WalletCard.encodeList(cards));
    // Keep the Android Autofill dataset in sync (no-op on other platforms).
    await AutofillBridge.syncCards(cards);
    // Re-plan expiry / bill-due reminders.
    await NotificationService.reschedule(cards);
    // Refresh the automatic encrypted backup (no-op unless enabled).
    await AutoBackupService.maybeBackup(cards);
  }
}

final cardVaultProvider =
    AsyncNotifierProvider<CardVaultNotifier, List<WalletCard>>(
        CardVaultNotifier.new);
