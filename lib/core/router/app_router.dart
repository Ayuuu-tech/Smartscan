import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scanmate/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:scanmate/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:scanmate/features/auth/presentation/screens/login_screen.dart';
import 'package:scanmate/features/auth/presentation/screens/create_account_screen.dart';
import 'package:scanmate/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:scanmate/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:scanmate/features/crop/presentation/screens/crop_screen.dart';
import 'package:scanmate/features/filter/presentation/screens/filter_screen.dart';
import 'package:scanmate/features/ocr/presentation/screens/ocr_screen.dart';
import 'package:scanmate/features/preview/presentation/screens/preview_screen.dart';
import 'package:scanmate/features/business_card/presentation/screens/business_card_scanner_screen.dart';
import 'package:scanmate/features/business_card/presentation/screens/business_card_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/create-account',
      builder: (context, state) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/crop',
      builder: (context, state) => const CropScreen(),
    ),
    GoRoute(
      path: '/filter',
      builder: (context, state) => const FilterScreen(),
    ),
    GoRoute(
      path: '/ocr',
      builder: (context, state) => const OcrScreen(),
    ),
    GoRoute(
      path: '/preview',
      builder: (context, state) => const PreviewScreen(),
    ),
    GoRoute(
      path: '/business-card-scanner',
      builder: (context, state) => const BusinessCardScannerScreen(),
    ),
    GoRoute(
      path: '/business-card-edit',
      builder: (context, state) => const BusinessCardEditScreen(),
    ),
  ],
  errorPageBuilder: (context, state) => const MaterialPage(
    child: Scaffold(
      body: Center(
        child: Text('Route not found'),
      ),
    ),
  ),
);
