import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scanmate/core/theme/app_colors.dart';
import 'package:scanmate/features/scanner/presentation/providers/scan_provider.dart';
import 'package:scanmate/core/services/ocr_service.dart';
import 'package:scanmate/core/services/image_processor_service.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  String _extractedText = '';
  late final TextEditingController _textController;
  bool _isEditing = false;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isLoading = true;
  File? _sourceImage;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _runOcr();
  }

  Future<void> _runOcr() async {
    final state = ref.read(scanProvider);
    // Prefer the filtered/final image; fall back to the first captured image
    final imageToProcess = state.finalImage ??
        (state.capturedImages.isNotEmpty ? state.capturedImages.first : null);
    _sourceImage = imageToProcess;

    if (imageToProcess == null) {
      if (mounted) {
        setState(() {
          _extractedText = 'No image available. Please scan a document first.';
          _textController.text = _extractedText;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final processor = ref.read(imageProcessorProvider);
      final enhanced = await processor.enhanceForOcr(imageToProcess);

      final ocrService = ref.read(ocrServiceProvider);
      final text = await ocrService.recognizeText(enhanced);

      if (mounted) {
        setState(() {
          _extractedText = text;
          _textController.text = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _extractedText = 'OCR failed: $e';
          _textController.text = 'OCR failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    // Keep edits made in the text field.
    final text = _isEditing ? _textController.text : _extractedText;
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text copied to clipboard'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _handleExportTxt() {
    final text = _isEditing ? _textController.text : _extractedText;
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Text copied. Paste into any editor to save as .txt'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // committing edits
        _extractedText = _textController.text;
      }
      _isEditing = !_isEditing;
      _isSearching = false;
    });
  }

  Widget _buildTextContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_extractedText.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text('No text found in this document.',
              style: TextStyle(color: AppColors.hint, fontSize: 14)),
        ),
      );
    }

    if (_isEditing) {
      return TextField(
        controller: _textController,
        maxLines: null,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
        ),
        style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.6),
      );
    }

    if (_isSearching && _searchQuery.isNotEmpty) {
      final String text = _extractedText;
      final List<TextSpan> spans = [];
      int start = 0;
      final String queryLower = _searchQuery.toLowerCase();
      final String textLower = text.toLowerCase();

      while (true) {
        final int index = textLower.indexOf(queryLower, start);
        if (index == -1) {
          spans.add(TextSpan(text: text.substring(start)));
          break;
        }
        if (index > start) {
          spans.add(TextSpan(text: text.substring(start, index)));
        }
        spans.add(TextSpan(
          text: text.substring(index, index + _searchQuery.length),
          style: TextStyle(
            backgroundColor: AppColors.primary.withValues(alpha: 0.25),
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ));
        start = index + _searchQuery.length;
      }

      return RichText(
        text: TextSpan(
          style: const TextStyle(
              color: AppColors.text, fontSize: 14, height: 1.6),
          children: spans,
        ),
      );
    }

    return SelectableText(
      _extractedText,
      style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: const Text('Extracted Text',
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
            onPressed: _isLoading ? null : _copyToClipboard,
          ),
          IconButton(
            tooltip: _isEditing ? 'Done' : 'Edit',
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined,
                color: _isEditing ? AppColors.primary : AppColors.text),
            onPressed: _isLoading ? null : _toggleEdit,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Small preview of the scanned page for context
              if (_sourceImage != null)
                Container(
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.file(_sourceImage!, fit: BoxFit.cover),
                ),

              // Text card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        child: Row(
                          children: [
                            const Text('Extracted text',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('EN',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Search',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: _isSearching
                                    ? AppColors.primary
                                    : AppColors.hint,
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                        _isSearching = !_isSearching;
                                        _isEditing = false;
                                        if (!_isSearching) _searchQuery = '';
                                      }),
                            ),
                          ],
                        ),
                      ),
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded,
                                    color: AppColors.hint, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Search text...',
                                      hintStyle: TextStyle(
                                          fontSize: 13, color: AppColors.hint),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    style: const TextStyle(
                                        fontSize: 13, color: AppColors.text),
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _isSearching = false;
                                    _searchQuery = '';
                                  }),
                                  child: const Icon(Icons.close_rounded,
                                      size: 18, color: AppColors.hint),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const Divider(height: 1, color: AppColors.border),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildTextContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actions
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _isSearching = true;
                          _isEditing = false;
                        }),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Search in doc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleExportTxt,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export as .txt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
