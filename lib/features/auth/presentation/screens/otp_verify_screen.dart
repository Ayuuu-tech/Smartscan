import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/core/services/otp_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// 6-digit email OTP entry. The code has already been sent by the
/// login/signup flow before navigating here.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _resendCooldown = 30;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    // Reached here without a live code (e.g. app restart / redirect gate) —
    // send one automatically so the screen is never a dead end.
    if (widget.email.isNotEmpty && !OtpService.hasPendingFor(widget.email)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) t.cancel();
    });
  }

  void _snack(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.secondary));
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _snack('Enter the 6-digit code.');
      return;
    }
    setState(() => _verifying = true);
    final error = OtpService.verify(widget.email, code);
    if (!mounted) return;
    if (error != null) {
      setState(() => _verifying = false);
      _snack(error);
      return;
    }
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) await OtpService.markDeviceVerified(uid);
    if (mounted) context.go('/dashboard');
  }

  Future<void> _resend() async {
    final error = await OtpService.sendOtp(widget.email);
    if (!mounted) return;
    if (error == null) {
      _startResendCooldown();
      _snack('New code sent to ${widget.email}.', error: false);
    } else {
      _snack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pin_outlined,
                          color: AppColors.primary, size: 36),
                    ),
                    const SizedBox(height: 24),
                    const Text('Enter verification code',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    const SizedBox(height: 12),
                    Text('We sent a 6-digit code to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.hint, fontSize: 14)),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 12,
                          color: AppColors.text),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _verifying ? null : _verify,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: _verifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                            : const Text('Verify'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _resendCooldown > 0 ? null : _resend,
                        child: Text(_resendCooldown > 0
                            ? 'Resend code (${_resendCooldown}s)'
                            : 'Resend code'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      child: const Text('Use a different account',
                          style: TextStyle(color: AppColors.hint)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
