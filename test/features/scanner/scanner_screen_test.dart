import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/scanner/presentation/screens/scanner_screen.dart';

void main() {
  testWidgets('Scanner screen renders and supports mode changes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ScannerScreen(),
        ),
      ),
    );

    expect(find.text('Align document inside frame'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('AUTO'), findsAtLeast(1));
    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('ID CARD'), findsOneWidget);

    await tester.tap(find.text('MANUAL'));
    await tester.pump(const Duration(milliseconds: 200));
  });
}
