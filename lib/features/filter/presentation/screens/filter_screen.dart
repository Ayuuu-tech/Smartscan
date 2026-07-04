import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';
import 'package:scanmate/core/services/image_processor_service.dart';
import 'package:scanmate/core/services/settings_service.dart';

class DotGridPainter extends CustomPainter {
  const DotGridPainter();

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

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  int _activeFilter = 1;
  double _brightness = 75.0;
  double _contrast = 60.0;
  bool _isProcessing = false;

  final List<String> _filterNames = [
    'original',
    'magicColor',
    'blackAndWhite',
    'gray',
    'retro',
  ];

  final List<String> _filterLabels = [
    'Original',
    'Magic Color',
    'B&W',
    'Gray',
    'Retro',
  ];

  @override
  void initState() {
    super.initState();
    // Start on the user's saved default filter.
    final defaultFilter =
        ref.read(settingsProvider).value?.defaultFilter ?? 'magicColor';
    final idx = _filterNames.indexOf(defaultFilter);
    if (idx != -1) _activeFilter = idx;
  }

  Future<void> _handleSaveContinue() async {
    final croppedImage = ref.read(scanProvider).croppedImage;
    if (croppedImage == null) {
      context.push('/preview');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final processor = ref.read(imageProcessorProvider);
      final quality = ref.read(settingsProvider).value?.jpegQuality ?? 92;
      final filtered = await processor.applyFilter(
        inputFile: croppedImage,
        filterType: _filterNames[_activeFilter],
        brightness: _brightness,
        contrast: _contrast,
        quality: quality,
      );
      ref.read(scanProvider.notifier).setFilteredImage(filtered);
    } catch (e) {
      debugPrint('Filter error: $e');
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      context.push('/preview');
    }
  }

  ColorFilter _getFilterForIndex(int index) {
    if (index == 0) {
      return const ColorFilter.matrix([
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    } else if (index == 2) {
      return const ColorFilter.matrix([
        1.5, 1.5, 1.5, 0.0, -128.0,
        1.5, 1.5, 1.5, 0.0, -128.0,
        1.5, 1.5, 1.5, 0.0, -128.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    } else if (index == 3) {
      return const ColorFilter.matrix([
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.2126, 0.7152, 0.0722, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    } else if (index == 4) {
      return const ColorFilter.matrix([
        0.393, 0.769, 0.189, 0.0, 0.0,
        0.349, 0.686, 0.168, 0.0, 0.0,
        0.272, 0.534, 0.131, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    } else {
      return const ColorFilter.matrix([
        1.1, 0.0, 0.0, 0.0, 5.0,
        0.0, 1.1, 0.0, 0.0, 5.0,
        0.0, 0.0, 1.1, 0.0, 5.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final croppedImage = ref.watch(scanProvider.select((s) => s.croppedImage));

    return Scaffold(
      backgroundColor: const Color(0xFF161616),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: DotGridPainter()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: const [
                      Icon(Icons.document_scanner_outlined, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Enhance Scan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12, top: 12,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF2A2A2A), size: 24),
                            onPressed: () => context.pop(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 16.0),
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildPreviewImage(croppedImage, false),
                                      const SizedBox(height: 12),
                                      const Text('ORIGINAL',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF8C8A82))),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 28),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ColorFiltered(
                                        colorFilter: _getFilterForIndex(_activeFilter),
                                        child: _buildPreviewImage(croppedImage, true),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('DIGITAL SCAN',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF2A2A2A))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          const Positioned.fill(
                            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20.0),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF7F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            children: List.generate(_filterLabels.length, (i) {
                              return Row(
                                children: [
                                  _buildFilterCard(i, _filterLabels[i]),
                                  if (i < _filterLabels.length - 1) const SizedBox(width: 12),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSliderRow(label: 'Brightness', value: _brightness, onChanged: (v) => setState(() => _brightness = v)),
                      _buildSliderRow(label: 'Contrast', value: _contrast, onChanged: (v) => setState(() => _contrast = v)),
                      const SizedBox(height: 16),
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
                                onPressed: _isProcessing ? null : _handleSaveContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDA856),
                                  foregroundColor: const Color(0xFF2A2A2A),
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  elevation: 0,
                                ),
                                child: _isProcessing
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2A2A2A)))
                                    : const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    );
  }

  Widget _buildPreviewImage(File? image, bool isDigital) {
    if (image == null) {
      return Container(
        width: 130, height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFEFE8D3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD6CDB7), width: 1.0),
        ),
        child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 32)),
      );
    }
    return Container(
      width: 130, height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDigital ? const Color(0xFFE5E2D9) : const Color(0xFFD6CDB7), width: 1.0),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(image, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildFilterCard(int index, String label) {
    final isActive = _activeFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isActive ? AppColors.primary : Colors.transparent, width: 2.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMiniDocument(isOriginal: true),
                    const SizedBox(width: 4),
                    const SizedBox(
                      width: 8, height: 8,
                      child: FittedBox(
                        child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    ColorFiltered(
                      colorFilter: _getFilterForIndex(index),
                      child: _buildMiniDocument(isOriginal: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: TextStyle(
              color: isActive ? AppColors.primary : const Color(0xFF8C8A82),
              fontSize: 10, fontWeight: FontWeight.bold,
            )),
        ],
      ),
    );
  }

  Widget _buildMiniDocument({required bool isOriginal}) {
    return Container(
      width: 20, height: 28,
      decoration: BoxDecoration(
        color: isOriginal ? const Color(0xFFEFE8D3) : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: isOriginal ? const Color(0xFFD6CDB7) : const Color(0xFFE5E2D9), width: 0.5),
      ),
      padding: const EdgeInsets.all(2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 10, height: 2, color: isOriginal ? const Color(0xFF8C8168) : const Color(0xFF2A2A2A)),
          const SizedBox(height: 2),
          Container(width: 14, height: 1.5, color: isOriginal ? const Color(0xFFC4B899) : const Color(0xFF8C8A82)),
          const SizedBox(height: 1),
          Container(width: 12, height: 1.5, color: isOriginal ? const Color(0xFFC4B899) : const Color(0xFF8C8A82)),
          const SizedBox(height: 1),
          Container(width: 8, height: 1.5, color: isOriginal ? const Color(0xFFC4B899) : const Color(0xFF8C8A82)),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
              style: const TextStyle(color: Color(0xFF8C8A82), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: Colors.white,
                overlayColor: AppColors.primary.withValues(alpha: 0.2),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(value: value, min: 0, max: 100, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('${value.round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
