import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanmate/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen renders slides', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    expect(find.text('Scan Anything in Seconds'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
