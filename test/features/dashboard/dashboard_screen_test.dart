import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/dashboard/presentation/screens/dashboard_screen.dart';

void main() {
  testWidgets('Dashboard screen renders main layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    expect(find.text('ScanMate'), findsOneWidget);
    expect(find.text('Scan'), findsAtLeast(1));
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('Starred'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
  });
}
