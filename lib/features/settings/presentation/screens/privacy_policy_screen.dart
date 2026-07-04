import 'package:flutter/material.dart';
import 'package:scanmate/core/constants/app_constants.dart';
import 'package:scanmate/core/theme/app_colors.dart';

/// In-app privacy policy describing exactly what ScanMate does with data.
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
              _p('${AppConstants.appName} is a document scanner that lets you '
                  'scan documents and business cards, extract text (OCR), and '
                  'optionally back them up to your own Google Drive. Your '
                  'privacy matters — here is exactly what happens with your data.'),

              _section('1. What we access', [
                _bullet('Camera', 'Used only while you are scanning a document '
                    'or business card. We never record in the background.'),
                _bullet('Photos / Gallery',
                    'Only images you explicitly pick to import are used.'),
                _bullet('Contacts',
                    'Only when you tap "Save to contacts" from a scanned '
                    'business card. We read contacts solely to detect '
                    'duplicates, and add the one contact you choose.'),
                _bullet('Google account',
                    'Used to sign you in and, if you enable cloud backup, to '
                    'store files in your own Google Drive.'),
              ]),

              _section('2. Where your data is stored', [
                _bullet('On your device',
                    'By default, all scans and PDFs are saved locally on your '
                    'phone. This is the primary copy.'),
                _bullet('Your Google Drive',
                    'If "Cloud backup" is ON, the PDF is uploaded to a folder '
                    'named "${AppConstants.appName}" in YOUR Google Drive. Only '
                    'you can access it. The app uses the drive.file scope, so '
                    'it can only see files it created — never the rest of your '
                    'Drive.'),
                _bullet('Cloud database (Firebase)',
                    'If cloud backup is ON, basic document info (title, date, '
                    'page count) is stored under your account so your document '
                    'list syncs across devices. Security rules ensure only you '
                    'can read your own data.'),
              ]),

              _section('3. What we do NOT do', [
                _bullet('No selling', 'We never sell or rent your data.'),
                _bullet('No ads tracking',
                    'We do not use your documents for advertising.'),
                _bullet('No hidden access',
                    'The app cannot read files in your Drive that it did not '
                    'create.'),
              ]),

              _section('4. Your control', [
                _bullet('Turn off cloud backup',
                    'Settings → Cloud backup. When off, nothing leaves your '
                    'device.'),
                _bullet('Delete anytime',
                    'Delete a document in the app, or remove files directly '
                    'from your Google Drive.'),
                _bullet('Sign out',
                    'Signing out stops all cloud sync immediately.'),
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
