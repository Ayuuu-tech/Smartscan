import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/ocr/presentation/screens/ocr_screen.dart';

void main() {
  testWidgets('OCR screen renders text extraction interface', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OcrScreen(),
        ),
      ),
    );

    expect(find.text('Extracted text'), findsOneWidget);
    expect(find.text('Search in doc'), findsOneWidget);
    expect(find.text('Export as .txt'), findsOneWidget);
  });
}
