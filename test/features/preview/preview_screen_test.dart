import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/preview/presentation/screens/preview_screen.dart';

void main() {
  testWidgets('Preview screen renders document view', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PreviewScreen(),
        ),
      ),
    );

    expect(find.text('Add Page'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('OCR Text'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
