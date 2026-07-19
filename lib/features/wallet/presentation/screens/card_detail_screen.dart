import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import 'package:go_router/go_router.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/biometric_service.dart';
import 'package:smartscan/core/services/card_vault_service.dart';
import 'package:smartscan/core/services/pro_gate.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';
import 'package:smartscan/features/wallet/presentation/widgets/card_visual.dart';
import 'package:smartscan/features/wallet/presentation/widgets/upi_pay_sheet.dart';

/// Copies [value] and clears the clipboard after [seconds] if it still
/// holds the same value (so we never wipe something the user copied later).
Future<void> copySensitive(BuildContext context, String label, String value,
    {int seconds = 30}) async {
  HapticFeedback.mediumImpact();
  await Clipboard.setData(ClipboardData(text: value));
  Future.delayed(Duration(seconds: seconds), () async {
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text == value) {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
  });
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied — clipboard clears in ${seconds}s'),
      backgroundColor: AppColors.success,
    ));
  }
}

class CardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const CardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  bool _revealed = false;

  Future<void> _toggleReveal() async {
    if (_revealed) {
      setState(() => _revealed = false);
      return;
    }
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Reveal card details');
    if (ok && mounted) {
      HapticFeedback.lightImpact();
      setState(() => _revealed = true);
    }
  }

  Future<void> _copyGuarded(String label, String value) async {
    // Copying the full number/CVV is as sensitive as revealing it.
    if (!_revealed) {
      final ok = await ref
          .read(biometricServiceProvider)
          .authenticate('Copy card details');
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    await copySensitive(context, label, value);
  }

  void _confirmDelete(WalletCard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text(
            'Remove "${card.title}" from your vault? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(cardVaultProvider.notifier).deleteCard(card.id);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBarcode(WalletCard card) {
    final data = card.barcodeData;
    if (data == null || data.isEmpty) return;
    final barcode = switch (card.barcodeFormat) {
      'qr' => Barcode.qrCode(),
      'ean13' => Barcode.ean13(),
      _ => Barcode.code128(),
    };
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(card.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87)),
              const SizedBox(height: 20),
              BarcodeWidget(
                barcode: barcode,
                data: data,
                width: card.barcodeFormat == 'qr' ? 220 : 260,
                height: card.barcodeFormat == 'qr' ? 220 : 90,
                drawText: false,
                errorBuilder: (_, _) => const Text(
                    'Could not render this code.\nCheck the number format.',
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              Text(data,
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              const Text('Show this at the counter',
                  style: TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardVaultProvider).value ?? [];
    final card = cards.where((c) => c.id == widget.cardId).firstOrNull;

    if (card == null) {
      // Deleted while open.
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Card not found')),
      );
    }

    final isPayment = card.type.isPayment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(card.title,
            style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(
              card.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: card.isFavorite ? const Color(0xFFFDA856) : AppColors.text,
            ),
            tooltip: 'Pin to top of wallet',
            onPressed: () =>
                ref.read(cardVaultProvider.notifier).toggleFavorite(card.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.text),
            onPressed: () => context.push('/card-entry',
                extra: CardEntryArgs(card: card, isNew: false)),
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () => _confirmDelete(card),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: isPayment ? _toggleReveal : () => _showBarcode(card),
            child: Hero(
              tag: 'card_${card.id}',
              child: CardVisual(card: card, revealed: _revealed),
            ),
          ),
          const SizedBox(height: 12),
          if (card.isExpired)
            _banner('This card has expired.', AppColors.error)
          else if (card.expiresSoon())
            _banner('This card expires soon (${card.expiryLabel}).',
                const Color(0xFFB9770E)),
          const SizedBox(height: 12),
          if (isPayment) ...[
            _actionTile(
              icon: _revealed
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              title: _revealed ? 'Hide card details' : 'Reveal card details',
              subtitle: 'Requires fingerprint / Face ID',
              onTap: _toggleReveal,
            ),
            _actionTile(
              icon: Icons.copy_rounded,
              title: 'Copy card number',
              subtitle: 'Auto-clears from clipboard in 30 seconds',
              onTap: () => _copyGuarded('Card number', card.number),
            ),
            if (card.hasExpiry)
              _actionTile(
                icon: Icons.event_outlined,
                title: 'Copy expiry (${card.expiryLabel})',
                onTap: () =>
                    copySensitive(context, 'Expiry', card.expiryLabel),
              ),
            if (card.cvv != null && card.cvv!.isNotEmpty)
              _actionTile(
                icon: Icons.password_rounded,
                title: 'Copy CVV',
                subtitle: 'Auto-clears from clipboard in 30 seconds',
                onTap: () => _copyGuarded('CVV', card.cvv!),
              ),
            if (card.cardholderName.isNotEmpty)
              _actionTile(
                icon: Icons.person_outline_rounded,
                title: 'Copy name (${card.cardholderName})',
                onTap: () =>
                    copySensitive(context, 'Name', card.cardholderName),
              ),
            const SizedBox(height: 8),
            _actionTile(
              icon: Icons.currency_rupee_rounded,
              title: 'Pay via UPI',
              subtitle: 'Opens GPay / PhonePe / Paytm',
              highlight: true,
              onTap: () => showUpiPaySheet(context),
            ),
          ] else ...[
            _actionTile(
              icon: Icons.qr_code_2_rounded,
              title: 'Show barcode / QR',
              subtitle: 'Present at the store counter',
              highlight: true,
              onTap: () => _showBarcode(card),
            ),
            if (card.barcodeData != null)
              _actionTile(
                icon: Icons.copy_rounded,
                title: 'Copy membership number',
                onTap: () => copySensitive(
                    context, 'Membership number', card.barcodeData!),
              ),
            _actionTile(
              icon: Icons.ios_share_rounded,
              title: 'Share card via QR',
              subtitle: 'Family scans it with SmartScan to add this card',
              onTap: () async {
                if (await ProGate.require(context, ref,
                    feature: 'Family card sharing')) {
                  _showShareQr(card);
                }
              },
            ),
          ],
          if (isPayment &&
              (card.creditLimit != null ||
                  card.billingDay != null ||
                  card.dueDay != null)) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CARD FINANCES',
                      style: TextStyle(
                          color: AppColors.hint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  if (card.creditLimit != null)
                    _infoRow('Credit limit', card.creditLimit!),
                  if (card.billingDay != null)
                    _infoRow('Statement day', 'Day ${card.billingDay}'),
                  if (card.dueDay != null)
                    _infoRow('Bill due day',
                        'Day ${card.dueDay} (reminder 1 day before)'),
                ],
              ),
            ),
          ],
          if (card.notes != null && card.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOTES',
                      style: TextStyle(
                          color: AppColors.hint,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Text(card.notes!,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// QR payload other SmartScan installs can import (loyalty/gift only —
  /// payment cards are never shareable).
  void _showShareQr(WalletCard card) {
    if (card.type.isPayment) return;
    final payload = json.encode({
      'app': 'smartscan_cards',
      'kind': 'shared_card',
      'v': 1,
      'card': card.toMap(),
    });
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share "${card.title}"',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: payload,
                width: 230,
                height: 230,
                errorBuilder: (_, _) =>
                    const Text('Card too large to share as QR'),
              ),
              const SizedBox(height: 12),
              const Text(
                'On the other phone: Wallet → Import QR',
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.hint, fontSize: 13)),
            ),
            Text(value,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _banner(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight ? AppColors.primary : AppColors.border,
            width: 1.5),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: highlight ? AppColors.primary : AppColors.text),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: highlight ? AppColors.primary : AppColors.text)),
        subtitle: subtitle == null
            ? null
            : Text(subtitle,
                style:
                    const TextStyle(color: AppColors.hint, fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
