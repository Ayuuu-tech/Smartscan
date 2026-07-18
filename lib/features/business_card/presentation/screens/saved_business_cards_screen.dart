import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/features/business_card/data/models/business_card_model.dart';
import 'package:smartscan/features/business_card/data/services/business_card_store_service.dart';

/// Visiting cards saved locally in the app.
class SavedBusinessCardsScreen extends ConsumerWidget {
  const SavedBusinessCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(businessCardStoreProvider).value ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: const Text('Visiting cards',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/business-card-scanner'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.document_scanner_outlined),
      ),
      body: cards.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contact_mail_outlined,
                      size: 56, color: AppColors.hint),
                  const SizedBox(height: 12),
                  const Text('No visiting cards yet',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Scan a card and it will be saved here too.',
                      style: TextStyle(color: AppColors.hint, fontSize: 13)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final card = cards[cards.length - 1 - i]; // newest first
                return _CardTile(
                  card: card,
                  onTap: () => _showDetail(context, ref, card),
                );
              },
            ),
    );
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, BusinessCardModel card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (card.imagePath != null &&
                  File(card.imagePath!).existsSync()) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(card.imagePath!),
                      height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
              ],
              Text(card.fullName ?? 'Unknown',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              if ((card.designation ?? '').isNotEmpty ||
                  (card.companyName ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                      [card.designation, card.companyName]
                          .where((s) => (s ?? '').isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                          color: AppColors.hint, fontSize: 14)),
                ),
              const SizedBox(height: 12),
              for (final phone in card.phoneNumbers)
                _DetailRow(
                    icon: Icons.phone_rounded,
                    text: phone,
                    onTap: () => launchUrl(Uri.parse('tel:$phone'))),
              for (final email in card.emailAddresses)
                _DetailRow(
                    icon: Icons.email_outlined,
                    text: email,
                    onTap: () => launchUrl(Uri.parse('mailto:$email'))),
              if ((card.website ?? '').isNotEmpty)
                _DetailRow(icon: Icons.language_rounded, text: card.website!),
              if ((card.address ?? '').isNotEmpty)
                _DetailRow(
                    icon: Icons.location_on_outlined, text: card.address!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Delete card?'),
                        content: Text(
                            'Remove ${card.fullName ?? 'this card'} from the app? Your phone contact is not affected.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(dctx, true),
                              child: const Text('Delete',
                                  style:
                                      TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (confirm == true && card.id != null) {
                      await ref
                          .read(businessCardStoreProvider.notifier)
                          .delete(card.id!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  label: const Text('Delete from app',
                      style: TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final BusinessCardModel card;
  final VoidCallback onTap;
  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = [card.companyName, card.phoneNumbers.firstOrNull]
        .where((s) => (s ?? '').isNotEmpty)
        .join(' · ');
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  (card.fullName ?? '?').trim().isEmpty
                      ? '?'
                      : (card.fullName ?? '?').trim()[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.fullName ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.hint, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _DetailRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 14))),
          ],
        ),
      ),
    );
  }
}
