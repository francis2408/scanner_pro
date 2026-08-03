import 'dart:convert';
import 'dart:typed_data';
import '../models/scan_result.dart';

/// PDF Export utility compiling scan results and document pages into printable PDF documents.
typedef PdfExporter = PdfExportUtil;

class PdfExportUtil {
  /// Compiles a list of [ScanResult] items or raw document images into PDF document bytes.
  static Uint8List exportResultsToPdf({
    required List<ScanResult> results,
    String title = 'ScannerPro Scanned Document Export',
    String author = 'Universal Scanner Pro SDK',
    bool isLandscape = false,
    bool includeMetadata = true,
  }) {
    final buffer = StringBuffer();
    final pageWidth = isLandscape ? 792 : 612;
    final pageHeight = isLandscape ? 612 : 792;

    // Generate valid minimalist PDF structure string
    buffer.writeln('%PDF-1.4');
    buffer.writeln('1 0 obj');
    buffer.writeln('<< /Type /Catalog /Pages 2 0 R >>');
    buffer.writeln('endobj');

    buffer.writeln('2 0 obj');
    buffer.writeln('<< /Type /Pages /Kids [3 0 R] /Count 1 >>');
    buffer.writeln('endobj');

    final contentStream = StringBuffer();
    contentStream.writeln('BT');
    contentStream.writeln('/F1 20 Tf');
    contentStream.writeln('50 ${pageHeight - 50} Td');
    contentStream.writeln('(${_escapePdfText(title)}) Tj');
    contentStream.writeln('0 -30 Td');
    contentStream.writeln('/F1 12 Tf');
    contentStream.writeln('(Exported on: ${DateTime.now().toIso8601String()}) Tj');
    contentStream.writeln('0 -20 Td');
    contentStream.writeln('(Generator: ${_escapePdfText(author)}) Tj');
    contentStream.writeln('0 -25 Td');
    contentStream.writeln('(Total Items Scanned: ${results.length}) Tj');
    contentStream.writeln('0 -30 Td');

    for (int i = 0; i < results.length && i < 20; i++) {
      final res = results[i];
      final lineText = '${i + 1}. [${res.mode.name.toUpperCase()}] ${_escapePdfText(res.rawValue.replaceAll('\n', ' '))}';
      final truncated = lineText.length > 75 ? '${lineText.substring(0, 72)}...' : lineText;
      contentStream.writeln('($truncated) Tj');
      contentStream.writeln('0 -18 Td');

      if (includeMetadata && res.fields.isNotEmpty) {
        final sampleField = res.fields.entries.first;
        contentStream.writeln('   (${_escapePdfText(sampleField.key)}: ${_escapePdfText(sampleField.value)}) Tj');
        contentStream.writeln('0 -15 Td');
      }
    }
    contentStream.writeln('ET');

    final streamBytes = utf8.encode(contentStream.toString());

    buffer.writeln('3 0 obj');
    buffer.writeln('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageWidth $pageHeight] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>');
    buffer.writeln('endobj');

    buffer.writeln('4 0 obj');
    buffer.writeln('<< /Length ${streamBytes.length} >>');
    buffer.writeln('stream');
    buffer.write(contentStream.toString());
    buffer.writeln('endstream');
    buffer.writeln('endobj');

    buffer.writeln('5 0 obj');
    buffer.writeln('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    buffer.writeln('endobj');

    buffer.writeln('trailer');
    buffer.writeln('<< /Root 1 0 R >>');
    buffer.writeln('%%EOF');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _escapePdfText(String text) {
    return text.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
  }
}
