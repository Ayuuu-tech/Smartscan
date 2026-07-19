import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/services/purchase_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// Gates premium features behind a Pro subscription.
///
/// Returns true if the user is Pro (let the action run). Otherwise shows a
/// short upsell sheet and returns false, so callers do: `if (!await
/// ProGate.require(...)) return;`
class ProGate {
  ProGate._();

  static bool isPro(WidgetRef ref) =>
      ref.read(proProvider).value?.isPro ?? false;

  static Future<bool> require(
    BuildContext context,
    WidgetRef ref, {
    required String feature,
    String? blurb,
  }) async {
    if (isPro(ref)) return true;
    if (!context.mounted) return false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: AppColors.primary, size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text('$feature is a Pro feature',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 8),
              Text(
                  blurb ??
                      'Upgrade to SmartScan Pro to unlock this and every other '
                          'premium feature — and remove ads.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.hint, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/pro');
                },
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('See Pro plans'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
    return false;
  }
}
