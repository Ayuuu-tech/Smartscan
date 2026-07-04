import 'package:flutter/material.dart';
import 'package:scanmate/core/theme/app_theme.dart';
import 'package:scanmate/core/router/app_router.dart';

class ScanMateApp extends StatelessWidget {
  const ScanMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ScanMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
