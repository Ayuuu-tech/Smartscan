import 'package:flutter/material.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/utils/card_utils.dart';
import 'package:smartscan/core/theme/card_themes.dart';

/// Realistic card face: gradient background, brand badge, masked (or
/// revealed) number, cardholder and expiry. Loyalty/gift cards show the
/// store name and a barcode hint instead of PAN details.
class CardVisual extends StatelessWidget {
  final WalletCard card;
  final bool revealed;

  const CardVisual({super.key, required this.card, this.revealed = false});

  @override
  Widget build(BuildContext context) {
    final brand = CardUtils.detectBrand(card.number);
    final isPayment = card.type.isPayment;

    return AspectRatio(
      aspectRatio: 1.586, // ISO 7810 ID-1
      child: Container(
        decoration: BoxDecoration(
          gradient: card.colorValue2 != null
              ? WalletCardTheme('', card.colorValue, card.colorValue2!)
                  .gradient
              : CardUtils.cardGradient(card.colorValue),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(card.colorValue).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.title.isEmpty ? card.type.label : card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _TypeChip(label: card.type.label),
              ],
            ),
            const Spacer(),
            if (isPayment) ...[
              // Chip graphic
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF6A),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                revealed
                    ? CardUtils.formatNumber(card.number)
                    : CardUtils.maskNumber(card.number),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (card.cardholderName.isNotEmpty)
                          Text(
                            card.cardholderName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        if (card.hasExpiry) ...[
                          const SizedBox(height: 2),
                          Text(
                            'VALID THRU ${card.expiryLabel}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    brand.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Icon(
                card.type == WalletCardType.gift
                    ? Icons.card_giftcard_rounded
                    : Icons.qr_code_2_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                card.barcodeData != null && card.barcodeData!.isNotEmpty
                    ? 'Tap to show ${card.barcodeFormat == 'qr' ? 'QR code' : 'barcode'}'
                    : (card.number.isNotEmpty
                        ? '•••• ${card.last4}'
                        : 'Membership card'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
