import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/core/services/otp_service.dart';
import 'package:smartscan/core/services/settings_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final authService = ref.read(authServiceProvider);
      final error = await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        if (error == null) {
          TextInput.finishAutofillContext();
          final email = _emailController.text.trim();
          final uid = authService.currentUser?.uid;
          // Email/password accounts verify with an OTP once per device.
          if (authService.usesPasswordProvider &&
              uid != null &&
              !await OtpService.isDeviceVerified(uid) &&
              OtpService.isConfigured) {
            final otpError = await OtpService.sendOtp(email);
            if (!mounted) return;
            if (otpError != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(otpError), backgroundColor: AppColors.error));
            } else {
              context.go('/verify-otp', extra: email);
            }
          } else if (mounted) {
            context.go('/dashboard');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authService = ref.read(authServiceProvider);
    final error = await authService.signInWithGoogle();
    if (mounted) {
      if (error == null) {
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller =
        TextEditingController(text: _emailController.text.trim());
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Reset password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Enter your account email and we\'ll send you a reset link. '
                  'Open the link to set a new password.',
                  style: TextStyle(color: AppColors.hint, fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon:
                      Icon(Icons.email_outlined, color: AppColors.hint),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: sending
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please enter a valid email address.'),
                              backgroundColor: AppColors.error),
                        );
                        return;
                      }
                      setDialogState(() => sending = true);
                      final error = await ref
                          .read(authServiceProvider)
                          .sendPasswordResetEmail(email);
                      if (!ctx.mounted || !mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error ??
                              'Reset link sent to $email. Check your inbox '
                                  'and spam folder.'),
                          backgroundColor: error == null
                              ? AppColors.secondary
                              : AppColors.error,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    },
              child: const Text('Send reset link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 72,
                          height: 72,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Welcome back',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 8),
                      const Text('Sign in to your SmartScan account',
                        style: TextStyle(color: AppColors.hint, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      AutofillGroup(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                hintText: 'Email address',
                                prefixIcon: Icon(Icons.email_outlined, color: AppColors.hint),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your email address';
                                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                                if (!emailRegex.hasMatch(value)) return 'Please enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.visiblePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSignIn(),
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.hint),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: AppColors.hint,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your password';
                                if (value.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Forgot password?'),
                        ),
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppColors.border, thickness: 1.5)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('or', style: TextStyle(color: AppColors.hint, fontSize: 14)),
                          ),
                          Expanded(child: Divider(color: AppColors.border, thickness: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _handleGoogleSignIn,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google_g.png', width: 20, height: 20),
                              const SizedBox(width: 12),
                              const Flexible(child: Text('Continue with Google',
                                style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                      // Apple Sign-In is only shown on iOS (Play builds omit it).
                      if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Apple Sign-in coming soon.')),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.apple,
                                    color: AppColors.text, size: 22),
                                const SizedBox(width: 12),
                                const Flexible(
                                    child: Text('Continue with Apple',
                                        style: TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Cards live only on this device, so an account is
                      // optional — don't force signup to use the wallet.
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(settingsProvider.notifier)
                              .setGuestMode(true);
                          if (context.mounted) context.go('/dashboard');
                        },
                        child: const Text('Continue without account →',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('New user? ',
                            style: TextStyle(color: AppColors.hint, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.push('/create-account'),
                            child: const Text('Create account',
                              style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
