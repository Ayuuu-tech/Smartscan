import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';
import 'package:scanmate/core/services/image_processor_service.dart';

class CropOverlayPainter extends CustomPainter {
  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;
  final bool showGrid;

  const CropOverlayPainter({
    required this.tl,
    required this.tr,
    required this.br,
    required this.bl,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final entireArea = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropArea = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final maskPath = Path.combine(PathOperation.difference, entireArea, cropArea);
    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(maskPath, maskPaint);

    final borderPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(cropArea, borderPaint);

    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      for (int i = 1; i <= 2; i++) {
        final double t = i / 3.0;
        final startH = Offset.lerp(tl, bl, t)!;
        final endH = Offset.lerp(tr, br, t)!;
        canvas.drawLine(startH, endH, gridPaint);
        final startV = Offset.lerp(tl, tr, t)!;
        final endV = Offset.lerp(bl, br, t)!;
        canvas.drawLine(startV, endV, gridPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.tl != tl ||
        oldDelegate.tr != tr ||
        oldDelegate.br != br ||
        oldDelegate.bl != bl ||
        oldDelegate.showGrid != showGrid;
  }
}

class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key});

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  double _tlX = 0.02, _tlY = 0.02;
  double _trX = 0.98, _trY = 0.02;
  double _brX = 0.98, _brY = 0.98;
  double _blX = 0.02, _blY = 0.98;

  int _rotationAngle = 0;
  bool _showGrid = true;
  bool _isProcessing = false;

  void _rotateLeft() {
    setState(() => _rotationAngle = (_rotationAngle - 90 + 360) % 360);
  }

  void _resetCrop() {
    setState(() {
      _tlX = 0.02; _tlY = 0.02;
      _trX = 0.98; _trY = 0.02;
      _brX = 0.98; _brY = 0.98;
      _blX = 0.02; _blY = 0.98;
    });
  }

  void _autoDetectCrop() {
    setState(() {
      _tlX = 0.10; _tlY = 0.10;
      _trX = 0.90; _trY = 0.10;
      _brX = 0.90; _brY = 0.90;
      _blX = 0.10; _blY = 0.90;
    });
  }

  Future<void> _handleCropSave() async {
    final currentImage = ref.read(scanProvider).currentImage;
    if (currentImage == null) {
      context.push('/filter');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final processor = ref.read(imageProcessorProvider);
      final cropped = await processor.correctPerspective(
        inputFile: currentImage,
        tlX: _tlX, tlY: _tlY,
        trX: _trX, trY: _trY,
        brX: _brX, brY: _brY,
        blX: _blX, blY: _blY,
      );
      ref.read(scanProvider.notifier).setCroppedImage(cropped);
    } catch (e) {
      debugPrint('Crop error: $e');
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      context.push('/filter');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = ref.watch(scanProvider.select((s) => s.currentImage));

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _DotGridPainter(),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text('Adjust Crop',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _autoDetectCrop,
                        icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                        label: const Text('AUTO',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Stack(
                        children: [
                          if (currentImage != null)
                            Positioned.fill(
                              child: RotatedBox(
                                quarterTurns: _rotationAngle ~/ 90,
                                child: Image.file(
                                  currentImage,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          else
                            const Center(child: Text('No image', style: TextStyle(color: Colors.grey))),
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final h = constraints.maxHeight;
                                final tl = Offset(_tlX * w, _tlY * h);
                                final tr = Offset(_trX * w, _trY * h);
                                final br = Offset(_brX * w, _brY * h);
                                final bl = Offset(_blX * w, _blY * h);

                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: CropOverlayPainter(
                                          tl: tl, tr: tr, br: br, bl: bl, showGrid: _showGrid,
                                        ),
                                      ),
                                    ),
                                    _buildDraggableHandle(
                                      position: tl,
                                      onDrag: (dx, dy) => setState(() {
                                        _tlX = ((tl.dx + dx) / w).clamp(0.0, 1.0);
                                        _tlY = ((tl.dy + dy) / h).clamp(0.0, 1.0);
                                      }),
                                    ),
                                    _buildDraggableHandle(
                                      position: tr,
                                      onDrag: (dx, dy) => setState(() {
                                        _trX = ((tr.dx + dx) / w).clamp(0.0, 1.0);
                                        _trY = ((tr.dy + dy) / h).clamp(0.0, 1.0);
                                      }),
                                    ),
                                    _buildDraggableHandle(
                                      position: br,
                                      onDrag: (dx, dy) => setState(() {
                                        _brX = ((br.dx + dx) / w).clamp(0.0, 1.0);
                                        _brY = ((br.dy + dy) / h).clamp(0.0, 1.0);
                                      }),
                                    ),
                                    _buildDraggableHandle(
                                      position: bl,
                                      onDrag: (dx, dy) => setState(() {
                                        _blX = ((bl.dx + dx) / w).clamp(0.0, 1.0);
                                        _blY = ((bl.dy + dy) / h).clamp(0.0, 1.0);
                                      }),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (_isProcessing)
                            const Positioned.fill(
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(icon: Icons.rotate_left_rounded, label: 'Rotate', onTap: _rotateLeft),
                      _buildIconButton(icon: Icons.flip_to_back_rounded, label: 'Reset', onTap: _resetCrop),
                      _buildIconButton(
                        icon: _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                        label: 'Grid',
                        onTap: () => setState(() => _showGrid = !_showGrid),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _handleCropSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDA856),
                            foregroundColor: const Color(0xFF2A2A2A),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 0,
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2A2A2A)),
                                )
                              : const Text('Next / Enhance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDraggableHandle({
    required Offset position,
    required void Function(double dx, double dy) onDrag,
  }) {
    return Positioned(
      left: position.dx - 24,
      top: position.dy - 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
        child: Container(
          width: 48, height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3.0),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, spreadRadius: 1)],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    const double spacing = 16.0;
    for (double x = 0.0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
