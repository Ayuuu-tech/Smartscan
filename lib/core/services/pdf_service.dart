import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

class PdfService {
  Future<File> generatePdf(List<File> imageFiles) async {
    final pdf = pw.Document();

    for (final imageFile in imageFiles) {
      final imageBytes = await imageFile.readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final file = File('${outputDir.path}/scanned_doc_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
