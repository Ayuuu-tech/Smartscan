import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanmate/core/services/firebase_service.dart';
import 'package:scanmate/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(
    const ProviderScope(
      child: ScanMateApp(),
    ),
  );
}
