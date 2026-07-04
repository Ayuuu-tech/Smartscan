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

  void dispose() {
    _textRecognizer.close();
  }
}
