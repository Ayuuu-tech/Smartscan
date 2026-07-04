import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/crop/presentation/screens/crop_screen.dart';

void main() {
  testWidgets('Crop screen renders elements and responds to controls', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CropScreen(),
        ),
      ),
    );

    expect(find.text('Adjust Crop'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Next / Enhance'), findsOneWidget);

    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
  });
}
