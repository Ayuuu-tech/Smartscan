import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scanmate/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // Guard against Firebase not being initialized (e.g. unsupported platform
    // or a failed init) so the splash never gets stuck on the logo.
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('Splash: could not read auth state: $e');
      user = null;
    }

    if (!mounted) return;
    context.go(user != null ? '/dashboard' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 140,
                height: 140,
              ),
            ),
            const SizedBox(height: 24),
            const Text('ScanMate',
              style: TextStyle(color: AppColors.text, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            const Text('Flat. Warm. Minimal.',
              style: TextStyle(color: AppColors.hint, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
