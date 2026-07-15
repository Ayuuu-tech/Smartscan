import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartscan/core/theme/app_colors.dart';

/// Live QR / barcode scanner: the camera detects codes automatically
/// (no shutter button), with a torch toggle and a "pick from gallery"
/// option. Pops with a `(value, format)` record — format is one of
/// 'qr' | 'ean13' | 'code128'.
class QrScanScreen extends StatefulWidget {
  final String title;
  const QrScanScreen({super.key, this.title = 'Scan QR / Barcode'});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _formatOf(BarcodeFormat format) => switch (format) {
        BarcodeFormat.qrCode => 'qr',
        BarcodeFormat.ean13 => 'ean13',
        _ => 'code128',
      };

  void _finish(Barcode barcode) {
    if (_handled) return;
    final value = barcode.rawValue ?? barcode.displayValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop((value, _formatOf(barcode.format)));
  }

  Future<void> _pickFromGallery() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final capture = await _controller.analyzeImage(picked.path);
    if (!mounted) return;
    final barcode = capture?.barcodes.firstOrNull;
    if (barcode != null) {
      _finish(barcode);
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('No QR or barcode found in that image'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? const Color(0xFFFDA856) : Colors.white,
            ),
            tooltip: 'Torch',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode != null) _finish(barcode);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Camera unavailable: ${error.errorCode.name}\nUse "From gallery" below instead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
          // Aiming frame
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          // Bottom bar: hint + gallery import
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Point at a QR or barcode —\nit scans automatically.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('From gallery',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the live scanner and returns the detected `(value, format)`,
/// or null if the user backed out.
Future<(String, String)?> scanCodeLive(BuildContext context,
    {String title = 'Scan QR / Barcode'}) {
  return Navigator.of(context).push<(String, String)>(
    MaterialPageRoute(builder: (_) => QrScanScreen(title: title)),
  );
}
