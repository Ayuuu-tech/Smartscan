import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartscan/core/constants/app_constants.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/core/services/auto_backup_service.dart';
import 'package:smartscan/core/services/autofill_bridge.dart';
import 'package:smartscan/core/services/backup_service.dart';
import 'package:smartscan/core/services/biometric_service.dart';
import 'package:smartscan/core/services/card_vault_service.dart';
import 'package:smartscan/core/services/pro_gate.dart';
import 'package:smartscan/core/services/settings_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/features/settings/presentation/screens/privacy_policy_screen.dart';

/// The Settings tab: profile, security, backup, upgrade and about
/// sections. Extracted from the dashboard to keep both maintainable.
class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _autofillEnabled = false;
  bool _autoBackupOn = false;

  @override
  void initState() {
    super.initState();
    _refreshAutofillStatus();
    AutoBackupService.isEnabled().then((on) {
      if (mounted) setState(() => _autoBackupOn = on);
    });
  }

  Future<void> _refreshAutofillStatus() async {
    final enabled = await AutofillBridge.isServiceEnabled();
    if (mounted) setState(() => _autofillEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();
    final userName = user?.displayName ?? 'Guest';
    final userEmail =
        user?.email ?? 'Local account — cards stay on this phone';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: _cardDecoration(),
            padding:
                const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF2E5CB8),
                  child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24)),
                ),
                const SizedBox(height: 12),
                Text(userName,
                    style: const TextStyle(
                        color: Color(0xFF2A2A2A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 4),
                Text(userEmail,
                    style:
                        const TextStyle(color: AppColors.hint, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SECURITY'),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.fingerprint_rounded,
                  title: 'App lock (biometric)',
                  trailing: Switch(
                    value: settings.appLock,
                    onChanged: _toggleAppLock,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(
                  icon: Icons.password_rounded,
                  title: 'Allow storing CVV',
                  trailing: Switch(
                    value: settings.storeCvv,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(settingsProvider.notifier)
                          .setStoreCvv(val);
                      if (!val) {
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'CVV storage off — existing CVVs stay until you edit those cards')),
                        );
                      }
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                if (AutofillBridge.supported) ...[
                  const Divider(height: 1, color: AppColors.border),
                  _buildSettingsItem(
                    icon: Icons.edit_note_rounded,
                    title: 'Autofill in other apps',
                    trailing: _autofillEnabled
                        ? const Text('ON',
                            style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))
                        : const Icon(Icons.keyboard_arrow_right_rounded,
                            color: AppColors.hint),
                    onTap: () async {
                      await AutofillBridge.requestEnable();
                      await _refreshAutofillStatus();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('BACKUP'),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.backup_rounded,
                  title: 'Automatic backup',
                  trailing: Switch(
                    value: _autoBackupOn,
                    onChanged: _toggleAutoBackup,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(
                  icon: Icons.upload_file_rounded,
                  title: 'Export encrypted backup',
                  trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                      color: AppColors.hint),
                  onTap: _exportVault,
                ),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(
                  icon: Icons.download_rounded,
                  title: 'Restore from backup',
                  trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                      color: AppColors.hint),
                  onTap: _importVault,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('UPGRADE'),
          Container(
            decoration: _cardDecoration(),
            child: _buildSettingsItem(
              icon: Icons.workspace_premium_rounded,
              title: 'SmartScan Pro',
              trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                  color: AppColors.hint),
              onTap: () => context.push('/pro'),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('ABOUT'),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _buildSettingsItem(
                    title: 'Version',
                    trailing: Text(AppConstants.appVersion,
                        style: const TextStyle(
                            color: AppColors.hint, fontSize: 13)),
                    onTap: _showAbout),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(
                    title: 'Privacy policy',
                    trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                        color: AppColors.hint),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()))),
                const Divider(height: 1, color: AppColors.border),
                _buildSettingsItem(
                    title: 'Help & feedback',
                    trailing: const Icon(Icons.keyboard_arrow_right_rounded,
                        color: AppColors.hint),
                    onTap: () => _openUrl(
                        'mailto:ayushmaan.ggn@gmail.com?subject=SmartScan%20Help%20%26%20Feedback')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: ElevatedButton(
              onPressed: () async {
                final authService = ref.read(authServiceProvider);
                final router = GoRouter.of(context);
                // Cards stay in the local vault either way.
                await ref.read(settingsProvider.notifier).setGuestMode(false);
                await authService.signOut();
                ref.read(vaultUnlockedProvider.notifier).set(false);
                router.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFD32F2F),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(user == null ? 'Sign in' : 'Sign out',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ── F1: encrypted backup & restore ─────────────────────────────────────

  Future<String?> _promptPassphrase({required bool confirm}) async {
    final pass = TextEditingController();
    final pass2 = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirm ? 'Set backup passphrase' : 'Enter passphrase'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirm)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'The backup can only be opened with this passphrase. There is NO recovery if you forget it.',
                    style: TextStyle(fontSize: 13, color: AppColors.hint),
                  ),
                ),
              TextFormField(
                controller: pass,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Passphrase'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              if (confirm)
                TextFormField(
                  controller: pass2,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Confirm passphrase'),
                  validator: (v) =>
                      v != pass.text ? 'Passphrases don\'t match' : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, pass.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoBackup(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      if (!await ProGate.require(context, ref,
          feature: 'Automatic backups')) {
        return;
      }
      final pass = await _promptPassphrase(confirm: true);
      if (pass == null) return;
      await AutoBackupService.enable(pass);
      // Write the first backup right away.
      await AutoBackupService.maybeBackup(
          ref.read(cardVaultProvider).value ?? []);
      if (mounted) setState(() => _autoBackupOn = true);
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Auto-backup ON — an encrypted copy is refreshed on every change'),
        backgroundColor: AppColors.success,
      ));
    } else {
      await AutoBackupService.disable();
      if (mounted) setState(() => _autoBackupOn = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('Auto-backup OFF — backup file deleted')));
    }
  }

  Future<void> _exportVault() async {
    final messenger = ScaffoldMessenger.of(context);
    final cards = ref.read(cardVaultProvider).value ?? [];
    if (cards.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to back up yet')));
      return;
    }
    final pass = await _promptPassphrase(confirm: true);
    if (pass == null) return;
    try {
      final content = await VaultBackupService.export(cards, pass);
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/smartscan_backup_$stamp.smbk');
      await file.writeAsString(content);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'SmartScan encrypted card backup',
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Backup failed: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _importVault() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final pass = await _promptPassphrase(confirm: false);
    if (pass == null) return;
    try {
      final content = await File(path).readAsString();
      final cards = await VaultBackupService.import(content, pass);
      final added =
          await ref.read(cardVaultProvider.notifier).importCards(cards);
      messenger.showSnackBar(SnackBar(
        content: Text(added > 0
            ? 'Restored $added card${added == 1 ? '' : 's'}'
            : 'All cards from this backup already exist'),
        backgroundColor: AppColors.success,
      ));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.error,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Restore failed: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _toggleAppLock(bool val) async {
    if (val) {
      final can =
          await ref.read(biometricServiceProvider).canAuthenticate();
      if (!mounted) return;
      if (!can) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Set up a screen lock or fingerprint on this device first'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    } else {
      // Confirm identity before weakening security.
      final ok = await ref
          .read(biometricServiceProvider)
          .authenticate('Confirm to turn off app lock');
      if (!ok || !mounted) return;
    }
    await ref.read(settingsProvider.notifier).setAppLock(val);
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      );

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: 'Version ${AppConstants.appVersion}',
      applicationIcon: const Icon(Icons.wallet_rounded,
          color: AppColors.primary, size: 40),
      children: const [
        SizedBox(height: 12),
        Text('Your cards — bank, loyalty and visiting — scanned, '
            'encrypted and stored only on this device.'),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not open link'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              color: AppColors.hint,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8)),
    );
  }

  Widget _buildSettingsItem(
      {IconData? icon,
      required String title,
      required Widget trailing,
      VoidCallback? onTap}) {
    final itemContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: const Color(0xFF3F62F6), size: 22),
            const SizedBox(width: 12)
          ],
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: Color(0xFF2A2A2A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14))),
          trailing,
        ],
      ),
    );
    if (onTap != null) return InkWell(onTap: onTap, child: itemContent);
    return itemContent;
  }
}
