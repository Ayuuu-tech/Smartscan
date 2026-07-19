import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:smartscan/core/services/purchase_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// SmartScan Pro subscriptions via Google Play Billing / App Store.
/// Prices (₹25/month, ₹139/year) are configured in Play Console /
/// App Store Connect — the screen shows whatever the store returns.
class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  static String get _storeName =>
      !kIsWeb && Platform.isIOS ? 'App Store' : 'Play Store';

  static const _benefits = [
    (Icons.cloud_upload_rounded, 'Automatic encrypted backups',
        'Settings → Backup → Automatic backup'),
    (Icons.auto_awesome_rounded, 'Smart card suggestions',
        'Wallet → "Best card?" — tag rewards on your cards'),
    (Icons.notifications_active_rounded, 'Bill & expiry reminders',
        'Set a due day on any card to get reminders'),
    (Icons.palette_rounded, 'Custom card themes',
        '10 gradient themes for cards and your visiting card'),
    (Icons.family_restroom_rounded, 'Family card sharing',
        'Card → "Share card via QR" (loyalty & gift cards)'),
    (Icons.badge_rounded, 'Visiting card designer',
        'Wallet → "My QR" — design, theme and share your card'),
  ];

  Future<void> _buy(
      BuildContext context, WidgetRef ref, ProductDetails product) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref.read(proProvider.notifier).buy(product);
    if (error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proProvider).value ?? const ProState();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('SmartScan Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 4),
          Text(
              pro.isPro
                  ? 'You\'re a Pro member — thank you! 🎉'
                  : 'Everything in free, plus:',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: pro.isPro ? AppColors.success : AppColors.hint,
                  fontWeight: pro.isPro ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14)),
          const SizedBox(height: 24),
          for (final (icon, title, subtitle) in _benefits)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.text)),
                        Text(subtitle,
                            style: const TextStyle(
                                color: AppColors.hint, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (pro.isPro)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                        'Pro active — manage in $_storeName → Subscriptions',
                        style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                ],
              ),
            )
          else if (pro.storeAvailable) ...[
            for (final product in pro.products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton(
                  onPressed: () => _buy(context, ref, product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: product.id == PurchaseService.yearlyId
                        ? AppColors.primary
                        : AppColors.cardBackground,
                    foregroundColor: product.id == PurchaseService.yearlyId
                        ? Colors.white
                        : AppColors.primary,
                    elevation: 0,
                    side: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        product.id == PurchaseService.yearlyId
                            ? '${product.price} / year — best value'
                            : '${product.price} / month',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text('Auto-renews · cancel anytime',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.normal)),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed: () => ref.read(proProvider.notifier).restore(),
              child: const Text('Restore purchases',
                  style: TextStyle(color: AppColors.hint)),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.4),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('₹25/month · ₹139/year — coming soon',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Text(
              'Subscriptions go live once the app is on the $_storeName. Pro features unlock as soon as you subscribe.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.hint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
