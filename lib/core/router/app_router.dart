import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:smartscan/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:smartscan/features/auth/presentation/screens/login_screen.dart';
import 'package:smartscan/features/auth/presentation/screens/create_account_screen.dart';
import 'package:smartscan/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_detail_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_scan_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/my_card_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/pro_screen.dart';
import 'package:smartscan/features/business_card/presentation/screens/business_card_scanner_screen.dart';
import 'package:smartscan/features/business_card/presentation/screens/business_card_edit_screen.dart';

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
      path: '/card-entry',
      builder: (context, state) => CardEntryScreen(
        args: state.extra is CardEntryArgs
            ? state.extra as CardEntryArgs
            : const CardEntryArgs(),
      ),
    ),
    GoRoute(
      path: '/card-detail',
      builder: (context, state) =>
          CardDetailScreen(cardId: state.extra as String),
    ),
    GoRoute(
      path: '/card-scanner',
      builder: (context, state) => const CardScanScreen(),
    ),
    GoRoute(
      path: '/my-card',
      builder: (context, state) => const MyCardScreen(),
    ),
    GoRoute(
      path: '/pro',
      builder: (context, state) => const ProScreen(),
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
