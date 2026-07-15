import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeText(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    try {
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'Failed to recognize text: $e';
    }
  }

  /// Like [recognizeText] but returns lines sorted by their physical
  /// top-to-bottom position on the image. ML Kit emits blocks in detection
  /// order, which can shuffle a card's layout — position matters when
  /// parsing card fields (the name sits BELOW the number/expiry).
  Future<String> recognizeTextSorted(File imageFile) async {
    final InputImage inputImage = InputImage.fromFile(imageFile);
    try {
      final recognized = await _textRecognizer.processImage(inputImage);
      final lines = <({double top, double left, String text})>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add((
            top: line.boundingBox.top,
            left: line.boundingBox.left,
            text: line.text,
          ));
        }
      }
      lines.sort((a, b) {
        // Same visual row (within half a line height) → left to right.
        if ((a.top - b.top).abs() < 20) return a.left.compareTo(b.left);
        return a.top.compareTo(b.top);
      });
      return lines.map((l) => l.text).join('\n');
    } catch (e) {
      return 'Failed to recognize text: $e';
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
