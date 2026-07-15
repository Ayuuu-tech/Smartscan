import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartscan/features/onboarding/presentation/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen renders slides', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OnboardingScreen(),
      ),
    );

    expect(find.text('All Your Cards, One Wallet'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
