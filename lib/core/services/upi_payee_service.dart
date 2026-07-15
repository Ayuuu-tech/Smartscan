import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A frequently-paid UPI contact (maid, landlord, shop…).
class UpiPayee {
  final String name;
  final String vpa;

  const UpiPayee({required this.name, required this.vpa});

  Map<String, dynamic> toMap() => {'name': name, 'vpa': vpa};

  factory UpiPayee.fromMap(Map<String, dynamic> map) => UpiPayee(
        name: map['name'] as String? ?? '',
        vpa: map['vpa'] as String? ?? '',
      );
}

/// Saved UPI payees, kept in the same secure store as the vault.
class UpiPayeesNotifier extends AsyncNotifier<List<UpiPayee>> {
  static const _storageKey = 'upi_payees_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<List<UpiPayee>> build() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];
      return (json.decode(raw) as List)
          .map((e) => UpiPayee.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('UpiPayees load error: $e');
      return [];
    }
  }

  Future<void> savePayee(UpiPayee payee) async {
    final payees = [
      ...(state.value ?? <UpiPayee>[]).where((p) => p.vpa != payee.vpa),
      payee,
    ];
    await _persist(payees);
  }

  Future<void> removePayee(String vpa) async {
    await _persist(
        (state.value ?? <UpiPayee>[]).where((p) => p.vpa != vpa).toList());
  }

  Future<void> _persist(List<UpiPayee> payees) async {
    state = AsyncData(payees);
    await _storage.write(
      key: _storageKey,
      value: json.encode(payees.map((p) => p.toMap()).toList()),
    );
  }
}

final upiPayeesProvider =
    AsyncNotifierProvider<UpiPayeesNotifier, List<UpiPayee>>(
        UpiPayeesNotifier.new);
