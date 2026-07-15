import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartscan/core/services/firebase_service.dart';
import 'package:smartscan/core/services/notification_service.dart';
import 'package:smartscan/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await NotificationService.init();
  runApp(
    const ProviderScope(
      child: SmartScanApp(),
    ),
  );
}
