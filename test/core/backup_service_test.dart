import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/backup_service.dart';

void main() {
  final cards = [
    WalletCard(
      id: '1',
      type: WalletCardType.credit,
      title: 'HDFC Bank Millennia',
      cardholderName: 'YASH SHARMA',
      number: '4111111111111111',
      expiryMonth: 8,
      expiryYear: 2029,
      nickname: 'Netflix card',
      isFavorite: true,
      creditLimit: '₹2,00,000',
      billingDay: 5,
      dueDay: 25,
      rewardCategories: const ['online', 'dining'],
      createdAt: DateTime(2026, 1, 1),
    ),
    WalletCard(
      id: '2',
      type: WalletCardType.loyalty,
      title: 'Star Rewards',
      barcodeData: '123456789',
      barcodeFormat: 'code128',
      createdAt: DateTime(2026, 2, 2),
    ),
  ];

  test('export → import roundtrip preserves every field', () async {
    final backup = await VaultBackupService.export(cards, 'hunter42');
    final restored = await VaultBackupService.import(backup, 'hunter42');

    expect(restored.length, 2);
    final c = restored.first;
    expect(c.number, '4111111111111111');
    expect(c.nickname, 'Netflix card');
    expect(c.isFavorite, isTrue);
    expect(c.creditLimit, '₹2,00,000');
    expect(c.billingDay, 5);
    expect(c.dueDay, 25);
    expect(c.rewardCategories, ['online', 'dining']);
    expect(restored[1].barcodeData, '123456789');
  });

  test('wrong passphrase throws BackupException', () async {
    final backup = await VaultBackupService.export(cards, 'hunter42');
    expect(
      () => VaultBackupService.import(backup, 'wrong-pass'),
      throwsA(isA<BackupException>()),
    );
  });

  test('garbage input throws BackupException', () async {
    expect(
      () => VaultBackupService.import('not a backup', 'x'),
      throwsA(isA<BackupException>()),
    );
  });

  test('backup content is actually encrypted (no plaintext PAN)', () async {
    final backup = await VaultBackupService.export(cards, 'hunter42');
    expect(backup.contains('4111111111111111'), isFalse);
    expect(backup.contains('YASH'), isFalse);
  });

  test('roundtrip preserves the two-tone theme colors', () async {
    final themed = [
      cards.first.copyWith(colorValue: 0xFFE36A26, colorValue2: 0xFF7B241C),
    ];
    final backup = await VaultBackupService.export(themed, 'p@ss');
    final restored = await VaultBackupService.import(backup, 'p@ss');
    expect(restored.first.colorValue, 0xFFE36A26);
    expect(restored.first.colorValue2, 0xFF7B241C);
  });

  test('matchesQuery finds cards by nickname, bank and last digits', () {
    final c = cards.first;
    expect(c.matchesQuery('netflix'), isTrue);
    expect(c.matchesQuery('hdfc'), isTrue);
    expect(c.matchesQuery('1111'), isTrue);
    expect(c.matchesQuery('icici'), isFalse);
  });
}
