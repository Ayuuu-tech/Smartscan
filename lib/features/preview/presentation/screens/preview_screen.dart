import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';
import 'package:scanmate/core/services/auth_service.dart';
import 'package:scanmate/core/services/camera_service.dart';
import 'package:scanmate/core/services/document_service.dart';
import 'package:scanmate/core/services/drive_service.dart';
import 'package:scanmate/core/services/pdf_service.dart';
import 'package:scanmate/core/services/local_document_service.dart';
import 'package:scanmate/core/services/settings_service.dart';
import 'package:scanmate/core/models/document_model.dart';
import 'package:scanmate/core/models/local_document_model.dart';

class SignaturePainter extends CustomPainter {
  const SignaturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1F3A60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.35, size.height * 0.65);
    path.quadraticBezierTo(size.width * 0.5, size.height * 0.1, size.width * 0.65, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.8, size.height * 0.35, size.width * 0.95, size.height * 0.1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  String _filename = '';
  String? _documentId;
  bool _isExporting = false;
  bool _isSaving = false;
  File? _lastGeneratedPdf;
  String? _lastPdfSignature;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final scanState = ref.read(scanProvider);
    if (scanState.documentId != null && scanState.filename != null) {
      _documentId = scanState.documentId;
      _filename = scanState.filename!;
    } else {
      final date = DateTime.now();
      final formatted = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      _filename = 'Scan_$formatted.pdf';
      _documentId = date.millisecondsSinceEpoch.toString();
      
      Future.microtask(() {
        if (mounted) {
          ref.read(scanProvider.notifier).setDocumentDetails(_documentId!, _filename);
          _saveCurrentState();
        }
      });
    }
  }

  /// Returns a cached PDF when the pages are unchanged, otherwise regenerates.
  /// Avoids re-encoding every page on rename/reorder/share/export.
  Future<File> _buildPdf(List<File> images) async {
    final signature = images.map((f) => f.path).join('|');
    final cached = _lastGeneratedPdf;
    if (cached != null &&
        signature == _lastPdfSignature &&
        cached.existsSync()) {
      return cached;
    }
    final pdfService = ref.read(pdfServiceProvider);
    final pdfFile = await pdfService.generatePdf(images);
    _lastGeneratedPdf = pdfFile;
    _lastPdfSignature = signature;
    return pdfFile;
  }

  Future<void> _saveCurrentState() async {
    final images = ref.read(scanProvider).capturedImages;
    if (images.isEmpty || _documentId == null) return;

    if (mounted) setState(() => _isSaving = true);
    try {
      final pdfFile = await _buildPdf(images);

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final doc = LocalDocumentModel(
        id: _documentId!,
        title: _filename.replaceAll('.pdf', ''),
        date: dateStr,
        pageCount: images.length,
        type: 'PDF',
        pdfPath: pdfFile.path,
        thumbnailPath: images.first.path,
        imagePaths: images.map((f) => f.path).toList(),
      );

      await ref.read(localDocumentProvider.notifier).addDocument(doc);
    } catch (e) {
      debugPrint('Error saving current document state: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Backs the current document up to Firestore (metadata) + Google Drive
  /// (the PDF file). Returns a user-facing status message, or null if there
  /// is nothing to report (e.g. cloud backup is turned off).
  Future<({String message, Color color})?> _backupToCloud() async {
    // Respect the user's "Cloud backup" setting.
    final settings = ref.read(settingsProvider).value;
    final cloudEnabled = settings?.cloudBackup ?? true;
    if (!cloudEnabled) return null;

    final user = ref.read(authStateProvider);
    final pdfFile = _lastGeneratedPdf;
    if (_documentId == null || pdfFile == null) return null;
    if (user == null) {
      return (
        message: 'Sign in to sync this document to the cloud',
        color: AppColors.error,
      );
    }

    try {
      // Upload the PDF file to the user's own Google Drive (free, 15 GB).
      // Best-effort: if Drive isn't authorized we still sync metadata.
      final driveId = await ref
          .read(driveServiceProvider)
          .uploadPdf(pdfFile, '$_documentId.pdf');

      final images = ref.read(scanProvider).capturedImages;
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final cloudDoc = DocumentModel(
        id: _documentId!,
        title: _filename.replaceAll('.pdf', ''),
        date: dateStr,
        pageCount: images.length,
        type: 'PDF',
        thumbnailType: 'pdf',
        fileUrl: driveId, // Google Drive file id (null if not uploaded)
      );

      await ref.read(documentServiceProvider).addDocument(cloudDoc);

      return driveId != null
          ? (message: 'Synced to cloud + Google Drive', color: AppColors.success)
          : (
              message: 'Synced (metadata only — Drive not connected)',
              color: AppColors.secondary,
            );
    } catch (e) {
      debugPrint('Cloud backup failed: $e');
      return (message: 'Cloud sync failed: $e', color: AppColors.error);
    }
  }

  Future<void> _handleDone() async {
    if (_isSaving) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving document, please wait...')),
      );
      return;
    }
    
    // Ensure the document is saved
    await _saveCurrentState();

    // Cloud backup (local copy is always the source of truth)
    final cloudStatus = await _backupToCloud();

    // Clear the scan session so the next scan is clean
    ref.read(scanProvider.notifier).clearScanSession();

    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(cloudStatus?.message ?? 'Document saved successfully'),
          backgroundColor: cloudStatus?.color ?? AppColors.success,
        ),
      );
      router.go('/dashboard');
    }
  }

  /// Add Page: pick from gallery or launch scanner
  Future<void> _handleAddPage() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: const Text('Pick from Gallery',
                    style: TextStyle(color: AppColors.text)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined,
                    color: AppColors.primary),
                title: const Text('Scan New Page',
                    style: TextStyle(color: AppColors.text)),
                onTap: () => Navigator.pop(ctx, 'scanner'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'gallery') {
      final picker = ImagePicker();
      final List<XFile> picked =
          await picker.pickMultiImage();
      if (picked.isNotEmpty && mounted) {
        final notifier = ref.read(scanProvider.notifier);
        for (final xfile in picked) {
          // Gallery picks live in a cache dir; persist so they survive.
          final persisted = await CameraService.persistImage(File(xfile.path));
          notifier.addCapturedImage(persisted);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${picked.length} page(s) added'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } else if (choice == 'scanner') {
      // Pop back to scanner so user can scan additional pages
      context.pop();
    }
  }

  /// Share: generate PDF then share the actual file + save locally
  Future<void> _handleShare() async {
    setState(() => _isExporting = true);
    try {
      final images = ref.read(scanProvider).capturedImages;
      if (images.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pages to share. Scan a document first.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final pdfFile = await _buildPdf(images);

      // Also save locally so it appears in documents
      await _saveCurrentState();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfFile.path, mimeType: 'application/pdf')],
          subject: _filename,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Share failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Reorder pages via drag-and-drop bottom sheet
  void _handleReorder() {
    final images = ref.read(scanProvider).capturedImages;
    if (images.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ReorderSheet(
        images: List<File>.from(images),
        onReordered: (reordered) async {
          final notifier = ref.read(scanProvider.notifier);
          notifier.reorderImages(reordered);
          await _saveCurrentState(); // Update draft in local storage
        },
      ),
    );
  }

  void _handleRename() {
    final controller = TextEditingController(text: _filename.replaceAll('.pdf', ''));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new filename', suffixText: '.pdf'),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (controller.text.trim().isNotEmpty) {
                final newName = '${controller.text.trim()}.pdf';
                setState(() => _filename = newName);
                if (_documentId != null) {
                  ref.read(scanProvider.notifier).setDocumentDetails(_documentId!, newName);
                }
                await _saveCurrentState(); // Update draft in local storage
              }
              navigator.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(scanProvider.select((s) => s.capturedImages));
    final totalPages = images.length;
    final displayPage =
        totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1) + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: _handleRename,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_filename, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_rounded, color: AppColors.hint, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 28),
            tooltip: 'Save and Exit',
            onPressed: _handleDone,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FE), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Page $displayPage of $totalPages',
                      style: const TextStyle(color: Color(0xFF3F62F6), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3F62F6), size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: images.isNotEmpty
                    ? PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          if (index != _currentPage) {
                            setState(() => _currentPage = index);
                          }
                        },
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.file(images[index], fit: BoxFit.contain),
                            ),
                          );
                        },
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F0),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Icon(Icons.apartment_rounded, color: Color(0xFF1F3A60), size: 24),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(width: 72, height: 8, color: const Color(0xFFFAF7F0)),
                                    const SizedBox(height: 6),
                                    Container(width: 48, height: 8, color: const Color(0xFFFAF7F0)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(width: double.infinity, height: 6, color: const Color(0xFFFAF7F0)),
                            const SizedBox(height: 6),
                            Container(width: 220, height: 6, color: const Color(0xFFFAF7F0)),
                            const SizedBox(height: 6),
                            Container(width: 160, height: 6, color: const Color(0xFFFAF7F0)),
                            const Divider(height: 32),
                            const Text('INVOICE',
                              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 12),
                            _buildInvoiceRow('Premium Subscription (1 Year)', '\$99.00'),
                            _buildInvoiceRow('Local OCR processing pack', '\$12.50'),
                            _buildInvoiceRow('Cloud Storage Add-on', '\$5.00'),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFEEF2FE), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('\$116.50',
                                    style: TextStyle(color: Color(0xFF3F62F6), fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(width: 120, height: 40,
                                    child: CustomPaint(painter: SignaturePainter())),
                                  Container(width: 140, height: 1.5, color: const Color(0xFFE5E2D9)),
                                  const SizedBox(height: 6),
                                  Container(width: 60, height: 6, color: const Color(0xFFFAF7F0)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _buildBottomBarItem(
                    icon: Icons.add_box_outlined, label: 'Add Page',
                    onTap: _handleAddPage,
                  )),
                  Expanded(child: _buildBottomBarItem(
                    icon: Icons.format_list_bulleted_rounded, label: 'Reorder',
                    onTap: _handleReorder,
                  )),
                  Expanded(child: _buildBottomBarItem(
                    icon: Icons.document_scanner_outlined, label: 'OCR Text',
                    onTap: () => context.push('/ocr'),
                  )),
                  Expanded(child: _buildBottomBarItem(
                    icon: Icons.ios_share_rounded, label: 'Share', isHighlighted: true,
                    onTap: _handleShare,
                  )),
                  Expanded(child: _buildBottomBarItem(
                    icon: Icons.delete_outline_rounded, label: 'Delete',
                    onTap: () async {
                      final router = GoRouter.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Discard Scan'),
                          content: const Text('Are you sure you want to discard this scanned document?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                              child: const Text('Discard'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        if (_documentId != null) {
                          await ref.read(localDocumentProvider.notifier).deleteDocument(_documentId!);
                        }
                        ref.read(scanProvider.notifier).clearScanSession();
                        router.go('/dashboard');
                      }
                    },
                  )),
                ],
              ),
            ),
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String itemName, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(itemName, style: const TextStyle(fontSize: 12, color: AppColors.text))),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text)),
        ],
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    if (isHighlighted) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0xFFFAF0E6), shape: BoxShape.circle),
              child: const Icon(Icons.ios_share_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 4),
            const Text('Share', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.text)),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.text, size: 22),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.text)),
        ],
      ),
    );
  }
}

// ─── Reorder Bottom Sheet ─────────────────────────────────────────────────────

class _ReorderSheet extends StatefulWidget {
  final List<File> images;
  final void Function(List<File>) onReordered;
  const _ReorderSheet({required this.images, required this.onReordered});

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late List<File> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List<File>.from(widget.images);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => Column(
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                const Text('Reorder Pages',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onReordered(_pages);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Done',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _pages.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _pages.removeAt(oldIndex);
                  _pages.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final file = _pages[index];
                return Card(
                  key: ValueKey(file.path),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.border, width: 1.2),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(file,
                          width: 44, height: 56, fit: BoxFit.cover),
                    ),
                    title: Text('Page ${index + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    trailing: const Icon(Icons.drag_handle_rounded,
                        color: AppColors.hint),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
