import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/core/services/ocr_service.dart';
import 'package:scanmate/features/business_card/data/services/business_card_parser_service.dart';
import 'package:scanmate/features/business_card/presentation/providers/business_card_provider.dart';

class BusinessCardScannerScreen extends ConsumerStatefulWidget {
  const BusinessCardScannerScreen({super.key});

  @override
  ConsumerState<BusinessCardScannerScreen> createState() =>
      _BusinessCardScannerScreenState();
}

class _BusinessCardScannerScreenState
    extends ConsumerState<BusinessCardScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchCardScanner() async {
    ref.read(businessCardProvider.notifier).setScanning(true);

    final options = DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.full,
      isGalleryImport: false,
    );

    final scanner = DocumentScanner(options: options);

    try {
      final result = await scanner.scanDocument();

      if (result.images != null && result.images!.isNotEmpty && mounted) {
        final imagePath = result.images!.first;

        final appDir = await getApplicationDocumentsDirectory();
        final cardDir = Directory('${appDir.path}/business_cards');
        if (!cardDir.existsSync()) cardDir.createSync();

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final savedPath = '${cardDir.path}/card_$timestamp.jpg';
        await File(imagePath).copy(savedPath);

        ref.read(businessCardProvider.notifier).setCapturedImage(savedPath);

        await _processCard(File(savedPath));
      } else {
        ref.read(businessCardProvider.notifier).setScanning(false);
      }
    } catch (e) {
      if (mounted) {
        ref.read(businessCardProvider.notifier).setScanning(false);
        ref.read(businessCardProvider.notifier).setError('Scan failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      scanner.close();
    }
  }

  Future<void> _processCard(File imageFile) async {
    ref.read(businessCardProvider.notifier).setProcessing(true);

    final ocrService = OcrService();
    try {
      final recognizedText = await ocrService.recognizeText(imageFile);

      if (!mounted) return;

      ref.read(businessCardProvider.notifier).setRawOcrText(recognizedText);

      if (recognizedText.isEmpty ||
          recognizedText.startsWith('Failed to recognize')) {
        ref.read(businessCardProvider.notifier).setProcessing(false);
        ref.read(businessCardProvider.notifier)
            .setError('Could not read text from this card. Please try again with better lighting.');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read card. Try better lighting.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final parser = BusinessCardParserService();
      final parsed = parser.parse(recognizedText);
      parsed.imagePath = imageFile.path;

      if (!mounted) return;

      ref.read(businessCardProvider.notifier).setParsedCard(parsed);

      if (mounted) {
        context.push('/business-card-edit');
      }
    } catch (e) {
      if (mounted) {
        ref.read(businessCardProvider.notifier).setProcessing(false);
        ref.read(businessCardProvider.notifier).setError('Processing error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      ocrService.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(businessCardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Business Card Scanner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.isProcessing)
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: Colors.white12,
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: _glowAnimation.value),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    color: AppColors.primary,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 60,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 36),
                      const Text(
                        'Business Card Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Position the card within the frame.\nEdges will be detected automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: AppColors.secondary, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Auto-detect & crop edges',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap:
                        state.isProcessing ? null : _launchCardScanner,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: state.isProcessing
                              ? Colors.grey
                              : AppColors.primary,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: state.isProcessing
                                ? Colors.grey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state.isProcessing
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
                  Text(
                    state.isProcessing ? 'Processing...' : 'Tap to Scan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
