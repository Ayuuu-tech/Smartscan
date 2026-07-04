import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanmate/core/enums/scan_filter_type.dart';

class ScanState {
  final List<File> capturedImages;
  final File? currentImage;
  final File? croppedImage;
  final File? filteredImage;
  final File? finalImage;
  final ScanFilterType activeFilter;
  final double brightness;
  final double contrast;
  final bool isProcessing;
  final String? documentId;
  final String? filename;

  const ScanState({
    this.capturedImages = const [],
    this.currentImage,
    this.croppedImage,
    this.filteredImage,
    this.finalImage,
    this.activeFilter = ScanFilterType.magicColor,
    this.brightness = 75.0,
    this.contrast = 60.0,
    this.isProcessing = false,
    this.documentId,
    this.filename,
  });

  ScanState copyWith({
    List<File>? capturedImages,
    File? currentImage,
    File? croppedImage,
    File? filteredImage,
    File? finalImage,
    ScanFilterType? activeFilter,
    double? brightness,
    double? contrast,
    bool? isProcessing,
    String? documentId,
    String? filename,
  }) {
    return ScanState(
      capturedImages: capturedImages ?? this.capturedImages,
      currentImage: currentImage ?? this.currentImage,
      croppedImage: croppedImage ?? this.croppedImage,
      filteredImage: filteredImage ?? this.filteredImage,
      finalImage: finalImage ?? this.finalImage,
      activeFilter: activeFilter ?? this.activeFilter,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      isProcessing: isProcessing ?? this.isProcessing,
      documentId: documentId ?? this.documentId,
      filename: filename ?? this.filename,
    );
  }
}

class ScanNotifier extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  void addCapturedImage(File image) {
    state = state.copyWith(
      capturedImages: [...state.capturedImages, image],
      currentImage: image,
    );
  }

  void setCurrentImage(File image) {
    state = state.copyWith(currentImage: image);
  }

  void setCroppedImage(File image) {
    state = state.copyWith(croppedImage: image);
  }

  void setFilteredImage(File image) {
    state = state.copyWith(filteredImage: image, finalImage: image);
  }

  void setActiveFilter(ScanFilterType filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void setBrightness(double value) {
    state = state.copyWith(brightness: value);
  }

  void setContrast(double value) {
    state = state.copyWith(contrast: value);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setDocumentDetails(String id, String filename) {
    state = state.copyWith(documentId: id, filename: filename);
  }

  void clearScanSession() {
    state = const ScanState();
  }

  void removeImage(int index) {
    final images = [...state.capturedImages];
    if (index < images.length) {
      images.removeAt(index);
      state = state.copyWith(
        capturedImages: images,
        currentImage: images.isNotEmpty ? images.last : null,
      );
    }
  }

  void reorderImages(List<File> reordered) {
    state = state.copyWith(
      capturedImages: reordered,
      currentImage: reordered.isNotEmpty ? reordered.first : null,
    );
  }
}

final scanProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);

