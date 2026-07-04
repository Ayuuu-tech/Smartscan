import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/filter/presentation/screens/filter_screen.dart';

void main() {
  testWidgets('Filter screen renders filter chips and sliders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FilterScreen(),
        ),
      ),
    );

    expect(find.text('Enhance Scan'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Magic Color'), findsOneWidget);
    expect(find.text('B&W'), findsOneWidget);
    expect(find.text('Gray'), findsOneWidget);
    expect(find.text('Retro'), findsOneWidget);
    expect(find.text('ORIGINAL'), findsOneWidget);
    expect(find.text('DIGITAL SCAN'), findsOneWidget);
    expect(find.text('Brightness'), findsOneWidget);
    expect(find.text('Contrast'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Save & Continue'), findsOneWidget);
  });
}
