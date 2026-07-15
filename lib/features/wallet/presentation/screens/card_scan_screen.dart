import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/ocr_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/utils/card_utils.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';

/// Scans a physical credit/debit card with the camera, OCRs it, extracts a
/// Luhn-valid number + expiry + name, and opens the entry form pre-filled.
///
/// The card photo is processed in memory and NOT kept on disk.
class CardScanScreen extends ConsumerStatefulWidget {
  const CardScanScreen({super.key});

  @override
  ConsumerState<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends ConsumerState<CardScanScreen> {
  bool _processing = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final photos = <File>[];
    try {
      // Same cross-platform scanner as visiting cards
      // (ML Kit doc scanner on Android / VisionKit on iOS).
      // Two pages: front AND back — Indian cards often print the number,
      // expiry and name on the back.
      final images = await CunningDocumentScanner.getPictures(
        noOfPages: 2,
        isGalleryImportAllowed: true,
      );
      if (images == null || images.isEmpty) {
        if (mounted) setState(() => _processing = false);
        return;
      }
      photos.addAll(images.map(File.new));

      // OCR every captured side and merge, so it doesn't matter which
      // side holds which detail. Lines are sorted by their physical
      // position — the parser relies on layout (name below number).
      final ocr = OcrService();
      final buffer = StringBuffer();
      for (final photo in photos) {
        buffer.writeln(await ocr.recognizeTextSorted(photo));
      }
      ocr.dispose();

      // Debug builds only: see exactly what OCR read when a field
      // doesn't get picked up.
      assert(() {
        debugPrint('Card OCR text:\n$buffer');
        return true;
      }());

      final parsed = CardOcrParser.parse(buffer.toString());

      if (!mounted) return;

      if (!parsed.hasNumber) {
        setState(() {
          _processing = false;
          _error =
              'Could not read a valid card number.\nTry better lighting, or add the card manually.';
        });
        return;
      }

      final draft = WalletCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: WalletCardType.debit,
        title: parsed.title ?? '',
        cardholderName: parsed.cardholderName ?? '',
        number: parsed.number!,
        expiryMonth: parsed.expiryMonth,
        expiryYear: parsed.expiryYear,
        cvv: parsed.cvv,
        colorValue: CardUtils.presetColors.first,
        createdAt: DateTime.now(),
      );

      setState(() => _processing = false);
      // Replace so back returns to the wallet, not the scanner.
      context.pushReplacement('/card-entry',
          extra: CardEntryArgs(card: draft, isNew: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Scan failed: $e';
        });
      }
    } finally {
      // Never keep card photos on disk.
      for (final photo in photos) {
        try {
          if (photo.existsSync()) photo.deleteSync();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scan Bank Card',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_processing)
              const LinearProgressIndicator(
                  color: AppColors.primary, backgroundColor: Colors.white12),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 126,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.primary, width: 2),
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                        child: const Icon(Icons.credit_card_rounded,
                            color: AppColors.primary, size: 48),
                      ),
                      const SizedBox(height: 28),
                      const Text('Scan front & back of your card',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        'Capture the front, then the back.\nBank name, card number, expiry and cardholder name are read automatically — photos are discarded, never saved.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 14,
                            height: 1.5),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.pushReplacement(
                              '/card-entry',
                              extra: const CardEntryArgs()),
                          child: const Text('Add manually instead',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _processing ? null : _scan,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _processing
                                ? Colors.grey
                                : AppColors.primary,
                            width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _processing
                                ? Colors.grey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _processing
                                ? Icons.hourglass_top
                                : Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_processing ? 'Reading card…' : 'Tap to Scan',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
