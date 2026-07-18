import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/features/business_card/data/models/business_card_model.dart';

/// Local vault for scanned visiting cards.
///
/// Same storage model as the wallet card vault: one JSON blob in the
/// platform secure store, never touches the network. The scanned card
/// image is copied into the app documents dir so it survives after the
/// scanner's temp file is cleaned up.
class BusinessCardStoreNotifier extends AsyncNotifier<List<BusinessCardModel>> {
  static const _legacyStorageKey = 'business_cards_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Storage key scoped to the signed-in account, so each account only
  /// ever sees its own cards.
  late String _storageKey;

  @override
  Future<List<BusinessCardModel>> build() async {
    // Rebuilds automatically on login/logout/account switch.
    final uid = ref.watch(authStateProvider)?.uid;
    _storageKey = uid == null ? _legacyStorageKey : 'business_cards_v1_$uid';
    try {
      var raw = await _storage.read(key: _storageKey);
      if ((raw == null || raw.isEmpty) && uid != null) {
        final legacy = await _storage.read(key: _legacyStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
          await _storage.write(key: _storageKey, value: legacy);
          await _storage.delete(key: _legacyStorageKey);
          raw = legacy;
        }
      }
      if (raw == null || raw.isEmpty) return [];
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => BusinessCardModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BusinessCardStore load error: $e');
      return [];
    }
  }

  Future<void> add(BusinessCardModel card) async {
    final stored = card.copyWith(
      id: card.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      savedAt: DateTime.now(),
      imagePath: await _persistImage(card.imagePath),
    );
    await _persist([...state.value ?? <BusinessCardModel>[], stored]);
  }

  Future<void> delete(String id) async {
    final cards = state.value ?? <BusinessCardModel>[];
    final removed = cards.where((c) => c.id == id).toList();
    await _persist(cards.where((c) => c.id != id).toList());
    // Best-effort cleanup of the stored card image.
    for (final c in removed) {
      final path = c.imagePath;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
  }

  /// Copies the scanned image into a permanent app-private location.
  Future<String?> _persistImage(String? path) async {
    if (path == null) return null;
    try {
      final src = File(path);
      if (!await src.exists()) return null;
      final dir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory('${dir.path}/visiting_cards');
      await cardsDir.create(recursive: true);
      if (path.startsWith(cardsDir.path)) return path;
      final dest =
          '${cardsDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await src.copy(dest);
      return dest;
    } catch (e) {
      debugPrint('BusinessCardStore image copy error: $e');
      return null;
    }
  }

  Future<void> _persist(List<BusinessCardModel> cards) async {
    state = AsyncData(cards);
    await _storage.write(
      key: _storageKey,
      value: json.encode([for (final c in cards) c.toMap()]),
    );
  }
}

final businessCardStoreProvider =
    AsyncNotifierProvider<BusinessCardStoreNotifier, List<BusinessCardModel>>(
        BusinessCardStoreNotifier.new);
