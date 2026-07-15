import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/core/services/settings_service.dart';
import 'package:smartscan/features/dashboard/presentation/screens/dashboard_screen.dart';

class _FakeSettings extends SettingsNotifier {
  final AppSettings settings;
  _FakeSettings(this.settings);

  @override
  Future<AppSettings> build() async => settings;
}

void main() {
  testWidgets('Dashboard shows lock screen when app lock is on',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
              () => _FakeSettings(const AppSettings(appLock: true))),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Wallet Locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
  });

  testWidgets('Dashboard renders wallet when unlocked',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
              () => _FakeSettings(const AppSettings(appLock: false))),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('SmartScan'), findsOneWidget);
    expect(find.text('Scan card'), findsOneWidget);
    expect(find.text('Add manually'), findsOneWidget);
    expect(find.text('UPI Pay'), findsOneWidget);
  });
}
