import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/card_vault_service.dart';
import 'package:smartscan/core/services/settings_service.dart';
import 'package:smartscan/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/pro_screen.dart';
import 'package:smartscan/features/wallet/presentation/widgets/upi_pay_sheet.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(appLock: false);
}

class _FakeVault extends CardVaultNotifier {
  @override
  Future<List<WalletCard>> build() async => [
        WalletCard(
          id: '1',
          type: WalletCardType.credit,
          title: 'HDFC Bank Millennia',
          cardholderName: 'YASH SHARMA',
          number: '4111111111111111',
          expiryMonth: 8,
          expiryYear: 2029,
          isFavorite: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        WalletCard(
          id: '2',
          type: WalletCardType.loyalty,
          title: 'Star Rewards',
          barcodeData: '12345',
          barcodeFormat: 'code128',
          createdAt: DateTime(2026, 2, 1),
        ),
      ];
}

Widget _wrapWithVault(Widget child) => ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FakeSettings.new),
        cardVaultProvider.overrideWith(_FakeVault.new),
      ],
      child: MaterialApp(home: child),
    );

Widget _wrapPlain(Widget child) => ProviderScope(
      overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
      child: MaterialApp(home: child),
    );

/// Screens use lazy ListViews — give tests a tall viewport so all
/// fields/buttons are actually built.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Wallet dashboard with cards', () {
    testWidgets('renders payment and loyalty sections', (tester) async {
      await tester.pumpWidget(_wrapWithVault(const DashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Payment cards'), findsOneWidget);
      expect(find.text('Loyalty & gift cards'), findsOneWidget);
      expect(find.text('HDFC Bank Millennia'), findsOneWidget);
      expect(find.text('Star Rewards'), findsOneWidget);
      expect(find.text('2 cards in your vault'), findsOneWidget);
    });

    testWidgets('search filters cards', (tester) async {
      await tester.pumpWidget(_wrapWithVault(const DashboardScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Search cards'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'star');
      await tester.pumpAndSettle();

      expect(find.text('Star Rewards'), findsOneWidget);
      expect(find.text('HDFC Bank Millennia'), findsNothing);
    });
  });

  group('Card entry form', () {
    testWidgets('rejects a number that fails the Luhn check',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_wrapPlain(const CardEntryScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Bank / card name'), 'HDFC');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Card number'),
          '4111111111111112'); // bad checksum
      await tester.ensureVisible(find.text('Save to Vault'));
      await tester.tap(find.text('Save to Vault'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid card number'), findsOneWidget);
    });

    testWidgets('detects the brand while typing', (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_wrapPlain(const CardEntryScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Card number'), '4111');
      await tester.pumpAndSettle();

      // Badge in the field + brand on the live preview card.
      expect(find.text('VISA'), findsWidgets);
    });
  });

  group('Pro screen', () {
    testWidgets('shows coming-soon state when the store is unavailable',
        (tester) async {
      _tallScreen(tester);
      await tester.pumpWidget(_wrapPlain(const ProScreen()));
      await tester.pumpAndSettle();

      expect(find.text('SmartScan Pro'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsOneWidget);
      expect(find.text('Automatic encrypted backups'), findsOneWidget);
    });
  });

  group('UPI QR parsing', () {
    test('parses a merchant QR payload', () {
      final r = parseUpiQr('upi://pay?pa=shop@ybl&pn=Tea%20Stall&am=20');
      expect(r, isNotNull);
      expect(r!.$1, 'shop@ybl');
      expect(r.$2, 'Tea Stall');
      expect(r.$3, '20');
    });

    test('rejects non-UPI data', () {
      expect(parseUpiQr('https://example.com'), isNull);
      expect(parseUpiQr('upi://pay?pn=NoVpa'), isNull);
    });
  });
}
