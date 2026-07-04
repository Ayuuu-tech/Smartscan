import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

final imageProcessorProvider = Provider<ImageProcessorService>((ref) {
  return ImageProcessorService();
});

class ImageProcessorService {
  Future<File> applyFilter({
    required File inputFile,
    required String filterType,
    double brightness = 75.0,
    double contrast = 60.0,
    int quality = 92,
  }) async {
    final bytes = await inputFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return inputFile;

    switch (filterType) {
      case 'magicColor':
        image = _applyMagicColor(image, brightness, contrast);
        break;
      case 'blackAndWhite':
        image = _applyBlackAndWhite(image, brightness, contrast);
        break;
      case 'gray':
        image = _applyGrayscale(image, brightness, contrast);
        break;
      case 'retro':
        image = _applyRetro(image, brightness, contrast);
        break;
      case 'original':
      default:
        image = _applyBrightnessContrast(image, brightness, contrast);
        break;
    }

    return _saveImage(image, inputFile, 'filtered', quality: quality);
  }

  Future<File> correctPerspective({
    required File inputFile,
    required double tlX, required double tlY,
    required double trX, required double trY,
    required double brX, required double brY,
    required double blX, required double blY,
  }) async {
    final bytes = await inputFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return inputFile;

    final w = image.width;
    final h = image.height;

    final x1 = (tlX * w).round().clamp(0, w);
    final y1 = (tlY * h).round().clamp(0, h);
    final x2 = (trX * w).round().clamp(0, w);
    final y2 = (trY * h).round().clamp(0, h);
    final x3 = (brX * w).round().clamp(0, w);
    final y3 = (brY * h).round().clamp(0, h);
    final x4 = (blX * w).round().clamp(0, w);
    final y4 = (blY * h).round().clamp(0, h);

    final cropX = [x1, x2, x3, x4].reduce(min);
    final cropY = [y1, y2, y3, y4].reduce(min);
    final cropW = [x1, x2, x3, x4].reduce(max) - cropX;
    final cropH = [y1, y2, y3, y4].reduce(max) - cropY;

    if (cropW <= 0 || cropH <= 0) return inputFile;

    try {
      final cropped = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
      return _saveImage(cropped, inputFile, 'cropped');
    } catch (e) {
      return inputFile;
    }
  }

  Future<File> enhanceForOcr(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return inputFile;

    image = img.grayscale(image);
    image = img.adjustColor(image, contrast: 1.5);

    return _saveImage(image, inputFile, 'ocr_enhanced');
  }

  img.Image _applyMagicColor(img.Image image, double brightness, double contrast) {
    final b = ((brightness - 50) * 2.55).roundToDouble();
    final c = contrast / 50.0;
    return img.adjustColor(image, brightness: b / 255, contrast: c);
  }

  img.Image _applyBlackAndWhite(img.Image image, double brightness, double contrast) {
    image = img.grayscale(image);
    final b = ((brightness - 50) * 2.55).roundToDouble();
    final c = contrast / 50.0;
    image = img.adjustColor(image, brightness: b / 255, contrast: c);

    final threshold = (128 * c).clamp(0, 255).round();
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final l = p.r.toInt();
        final val = l > threshold ? 255 : 0;
        image.setPixelRgba(x, y, val, val, val, 255);
      }
    }
    return image;
  }

  img.Image _applyGrayscale(img.Image image, double brightness, double contrast) {
    image = img.grayscale(image);
    final b = ((brightness - 50) * 2.55).roundToDouble();
    final c = contrast / 50.0;
    return img.adjustColor(image, brightness: b / 255, contrast: c);
  }

  img.Image _applyRetro(img.Image image, double brightness, double contrast) {
    final b = ((brightness - 50) * 2.55).roundToDouble();
    final c = contrast / 50.0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toInt();
        final g = p.g.toInt();
        final bl = p.b.toInt();
        final a = p.a.toInt();

        final tr = (0.393 * r + 0.769 * g + 0.189 * bl).round().clamp(0, 255);
        final tg = (0.349 * r + 0.686 * g + 0.168 * bl).round().clamp(0, 255);
        final tb = (0.272 * r + 0.534 * g + 0.131 * bl).round().clamp(0, 255);
        image.setPixelRgba(x, y, tr, tg, tb, a);
      }
    }

    return img.adjustColor(image, brightness: b / 255, contrast: c);
  }

  img.Image _applyBrightnessContrast(img.Image image, double brightness, double contrast) {
    final b = ((brightness - 50) * 2.55).roundToDouble();
    final c = contrast / 50.0;
    return img.adjustColor(image, brightness: b / 255, contrast: c);
  }

  Future<File> _saveImage(img.Image image, File original, String suffix,
      {int quality = 92}) async {
    final dir = original.parent;
    final stem = original.uri.pathSegments.last.split('.').first;
    final outputFile = File('${dir.path}/${stem}_$suffix.jpg');
    final jpegData = img.encodeJpg(image, quality: quality);
    await outputFile.writeAsBytes(jpegData);
    return outputFile;
  }
}
