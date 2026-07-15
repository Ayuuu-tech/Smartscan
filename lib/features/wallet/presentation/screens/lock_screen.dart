import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartscan/core/services/biometric_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// Full-screen biometric gate shown over the wallet while locked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on entry.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Unlock your card wallet');
    if (!mounted) return;
    setState(() => _authenticating = false);
    if (ok) {
      HapticFeedback.lightImpact();
      ref.read(vaultUnlockedProvider.notifier).set(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.primary, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'Wallet Locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Authenticate to view your saved cards.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _authenticating ? null : _unlock,
                icon: const Icon(Icons.fingerprint_rounded),
                label:
                    Text(_authenticating ? 'Waiting…' : 'Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
