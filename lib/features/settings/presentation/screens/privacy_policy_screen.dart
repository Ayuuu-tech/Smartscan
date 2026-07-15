import 'package:flutter/material.dart';
import 'package:smartscan/core/constants/app_constants.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// In-app privacy policy describing exactly what SmartScan does with data.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String supportEmail = 'ayushmaan.ggn@gmail.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Privacy Policy',
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${AppConstants.appName} Privacy Policy',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        const Text('Last updated: July 2026',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.hint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _p('${AppConstants.appName} is a card wallet that lets you '
                  'scan and store your bank, loyalty and visiting cards. Your '
                  'privacy matters — here is exactly what happens with your data.'),

              _section('1. What we access', [
                _bullet('Camera', 'Used only while you are scanning a card. '
                    'Card photos are processed on-device and discarded — '
                    'they are never saved or uploaded.'),
                _bullet('Biometrics',
                    'Your fingerprint / Face ID is checked by the operating '
                    'system to unlock the wallet. We never see or store it.'),
                _bullet('Contacts',
                    'Only when you tap "Save to contacts" from a scanned '
                    'visiting card. We read contacts solely to detect '
                    'duplicates, and add the one contact you choose.'),
                _bullet('Google account',
                    'Used only to sign you in.'),
              ]),

              _section('2. Where your card data is stored', [
                _bullet('On your device only',
                    'Card numbers, expiry dates and barcodes are stored in an '
                    'encrypted vault backed by your phone\'s secure hardware '
                    '(Android Keystore / iOS Keychain). They are NEVER '
                    'uploaded to any server, including ours.'),
                _bullet('Autofill (Android)',
                    'If you enable autofill, an encrypted, CVV-free copy of '
                    'your payment cards stays on-device so Android can fill '
                    'checkout forms you choose to fill.'),
              ]),

              _section('3. What we do NOT do', [
                _bullet('No selling', 'We never sell or rent your data.'),
                _bullet('No uploading',
                    'Your card numbers never leave this phone.'),
                _bullet('No payment processing',
                    'Payments happen in your UPI app — we only pre-fill the '
                    'details you enter.'),
              ]),

              _section('4. Your control', [
                _bullet('App lock',
                    'Settings → Security. Require biometrics every time the '
                    'app opens.'),
                _bullet('CVV storage',
                    'Off by default. Enable it only if you want CVVs saved.'),
                _bullet('Delete anytime',
                    'Deleting a card removes it permanently from the vault. '
                    'Uninstalling the app erases the entire vault.'),
              ]),

              _section('5. Contact', [
                _bullet('Questions or requests',
                    'Email us and we will help: $supportEmail'),
              ]),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(supportEmail,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _p(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.text, fontSize: 14, height: 1.5)),
      );

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          ...children,
        ],
      );

  Widget _bullet(String heading, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(body,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 13, height: 1.45)),
          ],
        ),
      );
}
