import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartscan/app.dart';

void main() {
  testWidgets('App splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartScanApp(),
      ),
    );

    // Let the router's async redirect resolve so the splash builds.
    await tester.pump();
    expect(find.text('SmartScan'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
