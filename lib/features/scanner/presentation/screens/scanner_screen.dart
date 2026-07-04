import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scanmate/core/services/camera_service.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _launchDocumentScanner() async {
    final options = DocumentScannerOptions(
      documentFormats: {DocumentFormat.jpeg},
      mode: ScannerMode.full,
      isGalleryImport: false,
    );

    final scanner = DocumentScanner(options: options);

    try {
      final result = await scanner.scanDocument();

      if (result.images != null && result.images!.isNotEmpty && mounted) {
        final notifier = ref.read(scanProvider.notifier);
        for (final path in result.images!) {
          // ML Kit writes to a cache dir; persist before storing.
          final persisted = await CameraService.persistImage(File(path));
          notifier.addCapturedImage(persisted);
        }
        if (!mounted) return;
        context.push('/preview');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Document scanner error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      scanner.close();
    }
  }

  void _pickFromGallery() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        // Persist the gallery pick out of the cache dir before using it.
        final file = await CameraService.persistImage(File(image.path));
        if (!mounted) return;
        ref.read(scanProvider.notifier).addCapturedImage(file);
        context.push('/crop');
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount =
        ref.watch(scanProvider.select((s) => s.capturedImages.length));

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.document_scanner_rounded,
                                color: AppColors.primary,
                                size: 56,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Document Scanner',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Place your document in frame and tap Scan.\n'
                        'Edges will be detected and cropped automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: _pickFromGallery,
                        ),
                        GestureDetector(
                          onTap: _launchDocumentScanner,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 4,
                              ),
                            ),
                            child: Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.document_scanner_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (pageCount > 0) {
                              context.push('/preview');
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.description_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              if (pageCount > 0)
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$pageCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
