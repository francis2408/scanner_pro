import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Top 5 Enterprise Priorities - ScannerPro SDK', () {
    // -------------------------------------------------------------------------
    // Priority 1: OCR (Optical Character Recognition)
    // -------------------------------------------------------------------------
    group('1. OCR (Optical Character Recognition) & Structured Layout', () {
      test('Creates and serializes hierarchical OcrTextResult model', () {
        const element1 = TextElement(
          text: 'INVOICE',
          confidence: 0.99,
          boundingBox: Rect.fromLTWH(10, 10, 100, 20),
          recognizedLanguage: 'en',
        );
        const element2 = TextElement(
          text: '#1024',
          confidence: 0.97,
          boundingBox: Rect.fromLTWH(120, 10, 80, 20),
          recognizedLanguage: 'en',
        );
        const line = TextLine(
          text: 'INVOICE #1024',
          elements: [element1, element2],
          boundingBox: Rect.fromLTWH(10, 10, 190, 20),
          confidence: 0.98,
          recognizedLanguage: 'en',
        );
        const block = TextBlock(
          text: 'INVOICE #1024',
          lines: [line],
          boundingBox: Rect.fromLTWH(10, 10, 190, 20),
          confidence: 0.98,
        );
        const ocrResult = OcrTextResult(
          fullText: 'INVOICE #1024\nTotal: \$500.00',
          blocks: [block],
          overallConfidence: 0.98,
          primaryLanguage: 'latin',
        );

        expect(ocrResult.wordCount, equals(4));
        expect(ocrResult.lines.length, equals(1));
        expect(ocrResult.lines.first.elements.length, equals(2));

        final jsonMap = ocrResult.toJson();
        final restored = OcrTextResult.fromJson(jsonMap);

        expect(restored.fullText, equals(ocrResult.fullText));
        expect(restored.blocks.length, equals(1));
        expect(restored.blocks.first.lines.first.text, equals('INVOICE #1024'));
      });

      test('ScannerPro.scanOcr processes raw byte buffer into OCR ScanResult', () async {
        final sampleBytes = Uint8List.fromList('GENERAL TEXT BLOCK FOR OCR PROCESSING LINE 1 LINE 2'.codeUnits);
        final result = await ScannerPro.scanOcr(sampleBytes);

        expect(result.mode, equals(ScanMode.ocr));
        expect(result.isValid, isTrue);
        expect(result.rawValue, contains('GENERAL TEXT BLOCK'));
        expect(result.fields['Text Recognition Engine'], contains('Google ML Kit'));
      });
    });

    // -------------------------------------------------------------------------
    // Priority 2: Document Scanning & Quad Edge Detection
    // -------------------------------------------------------------------------
    group('2. Document Scanning & Corner Math', () {
      test('DocumentCorners computes area, convex status, and scaling', () {
        const corners = DocumentCorners(
          topLeft: Offset(10, 10),
          topRight: Offset(200, 10),
          bottomRight: Offset(200, 300),
          bottomLeft: Offset(10, 300),
        );

        expect(corners.area, equals(190 * 290.0));
        expect(corners.isConvex, isTrue);
        expect(corners.isValidQuad, isTrue);
        expect(corners.aspectRatio, closeTo(190 / 290, 0.01));

        final scaled = corners.scale(2.0, 2.0);
        expect(scaled.topLeft, equals(const Offset(20, 20)));
        expect(scaled.topRight, equals(const Offset(400, 20)));
      });

      test('DocumentScannerService.detectDocumentEdges and perspective transform', () {
        const imgSize = Size(1000, 1400);
        final corners = DocumentScannerService.detectDocumentEdges(imgSize);
        final transform = DocumentScannerService.computePerspectiveTransform(corners, imgSize);

        expect(corners.isValidQuad, isTrue);
        expect(transform.storage.length, equals(16));
        expect(corners.toBoundingBox().width, greaterThan(0));
      });

      test('ScannerPro.scanDocument processes document frame', () async {
        final dummyBytes = Uint8List(640 * 480);
        final result = await ScannerPro.scanDocument(dummyBytes);

        expect(result.mode, equals(ScanMode.document));
        expect(result.isValid, isTrue);
        expect(result.fields['Perspective Transform'], contains('Corrected'));
      });
    });

    // -------------------------------------------------------------------------
    // Priority 3: Multi-Format Barcode Support
    // -------------------------------------------------------------------------
    group('3. Multi-Format Barcode & Payload Support', () {
      test('ScannerPro.scanBarcode parses 1D and 2D QR symbologies', () async {
        final qrBytes = Uint8List.fromList('https://flutter.dev'.codeUnits);
        final result = await ScannerPro.scanBarcode(qrBytes, mode: ScanMode.qr);

        expect(result.mode, equals(ScanMode.qr));
        expect(result.format, equals('QR_CODE'));
        expect(result.fields['Value Type'], equals('WEB URL'));
        expect(result.fields['URL Link'], equals('https://flutter.dev'));
      });

      test('Parses multi-barcode batch payloads in single frame', () async {
        final multiPayload = Uint8List.fromList('WIFI:S:MyWifi;P:secret123;T:WPA;;;\n---\nhttps://pub.dev'.codeUnits);
        final result = await ScannerPro.scanBarcode(multiPayload, mode: ScanMode.multiCode);

        expect(result.mode, equals(ScanMode.multiCode));
        expect(result.barcodes.length, greaterThanOrEqualTo(1));
        expect(result.fields['Multi-Code Detection'], contains('Codes Found'));
      });

      test('Parses GS1 Application Identifier payloads', () async {
        final gs1Payload = Uint8List.fromList('(01)00012345678905(10)LOT1234'.codeUnits);
        final result = await ScannerPro.scanBarcode(gs1Payload, mode: ScanMode.barcode);

        expect(result.isValid, isTrue);
        expect(result.fields['Value Type'], contains('GS1'));
        expect(result.fields['GTIN (Product Code)'], equals('00012345678905'));
        expect(result.fields['Batch/Lot Number'], equals('LOT1234'));
      });
    });

    // -------------------------------------------------------------------------
    // Priority 4: Auto Document Enhancement
    // -------------------------------------------------------------------------
    group('4. Auto Document Enhancement & Quality Analysis', () {
      test('Applies document filter modes via DocumentScannerService', () {
        final rawGray = Uint8List.fromList(List.generate(100, (i) => i * 2));

        final grayscale = DocumentScannerService.applyFilter(rawGray, DocumentFilterMode.grayscale);
        final binarized = DocumentScannerService.applyFilter(rawGray, DocumentFilterMode.binarization, binarizationThreshold: 100);
        final magic = DocumentScannerService.applyFilter(rawGray, DocumentFilterMode.magicColor);
        final shadow = DocumentScannerService.applyFilter(rawGray, DocumentFilterMode.shadowRemoval);

        expect(grayscale.length, equals(rawGray.length));
        expect(binarized.every((b) => b == 0 || b == 255), isTrue);
        expect(magic.length, equals(rawGray.length));
        expect(shadow.length, equals(rawGray.length));
      });

      test('Applies custom brightness and contrast filter', () {
        final sample = Uint8List.fromList([50, 100, 150, 200]);
        final adjusted = DocumentScannerService.applyBrightnessContrastFilter(
          sample,
          brightness: 0.1,
          contrast: 1.2,
        );

        expect(adjusted.length, equals(sample.length));
        expect(adjusted[0], isNot(equals(50)));
      });

      test('ScannerPro.enhanceDocument and ScannerPro.analyzeQuality', () {
        final grayBuffer = Uint8List.fromList(List.generate(640 * 480, (i) => (i % 256)));
        final enhanced = ScannerPro.enhanceDocument(grayBuffer, DocumentFilterMode.magicColor);
        expect(enhanced.length, equals(grayBuffer.length));

        final report = ScannerPro.analyzeQuality(grayBuffer, width: 640, height: 480);
        expect(report.overallScore, greaterThan(0.0));
        expect(report.recommendations, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // Priority 5: Multi-Page PDF Generation
    // -------------------------------------------------------------------------
    group('5. Multi-Page PDF Generation, Encryption & Watermarking', () {
      test('Generates multi-page PDF document bytes from ScanResults', () {
        final items = List.generate(
          30, // 30 items -> exceeds 25 per page, tests multi-page pagination
          (i) => ScanResult(
            mode: ScanMode.document,
            rawValue: 'Page Document Item #$i',
            documentCategory: 'documentPage',
            fields: {'Item': '#$i', 'Status': 'Verified'},
          ),
        );

        final pdfBytes = ScannerPro.exportToPdfBytes(
          results: items,
          title: 'Enterprise Scanned Contract',
          watermarkText: 'CONFIDENTIAL',
          isEncrypted: true,
          password: 'securePassword123',
          digitalSignature: true,
        );

        final pdfStr = String.fromCharCodes(pdfBytes);
        expect(pdfBytes, isNotEmpty);
        expect(pdfStr, contains('%PDF-1.4'));
        expect(pdfStr, contains('CONFIDENTIAL'));
        expect(pdfStr, contains('Enterprise Scanned Contract'));
        expect(pdfStr, contains('/Encrypt'));
        expect(pdfStr, contains('/Sig'));
      });

      test('Batch exports grouped results into combined PDF', () {
        final grouped = {
          'Invoices': [
            ScanResult(mode: ScanMode.invoice, rawValue: 'Invoice #001', fields: {'Total': '\$100'})
          ],
          'Receipts': [
            ScanResult(mode: ScanMode.receipt, rawValue: 'Receipt #002', fields: {'Tax': '\$10'})
          ],
        };

        final pdfBytes = ScannerPro.batchExportToPdf(
          results: grouped.values.expand((x) => x).toList(),
          title: 'Monthly Expenses Batch',
          watermarkText: 'APPROVED',
        );

        expect(pdfBytes, isNotEmpty);
        expect(String.fromCharCodes(pdfBytes), contains('Monthly Expenses Batch'));
      });
    });

    // -------------------------------------------------------------------------
    // Round-Trip Data Integrity Test
    // -------------------------------------------------------------------------
    group('Data Integrity & Deserialization', () {
      test('ScanResult.fromJson preserves roi, corners, and imageSize', () {
        final original = ScanResult(
          mode: ScanMode.document,
          rawValue: 'Sample Document Payload',
          roi: const Rect.fromLTWH(10, 20, 300, 400),
          corners: const [
            Offset(10, 20),
            Offset(310, 20),
            Offset(310, 420),
            Offset(10, 420),
          ],
          imageSize: const Size(1920, 1080),
        );

        final jsonMap = original.toJson();
        final restored = ScanResult.fromJson(jsonMap);

        expect(restored.roi, equals(const Rect.fromLTWH(10, 20, 300, 400)));
        expect(restored.corners?.length, equals(4));
        expect(restored.corners?[0], equals(const Offset(10, 20)));
        expect(restored.imageSize, equals(const Size(1920, 1080)));
      });
    });
  });
}

