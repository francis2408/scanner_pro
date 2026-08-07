import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:scannerpro/scannerpro.dart';

class MockTestPlugin extends ScannerPlugin {
  bool wasInvoked = false;

  @override
  String get id => 'test_ocr_plugin';

  @override
  String get title => 'Mock Custom OCR Plugin';

  @override
  ScanMode get supportedMode => ScanMode.ocr;

  @override
  Future<void> initialize() async {}

  @override
  Future<ScanResult?> processInputImage(InputImage inputImage) async {
    wasInvoked = true;
    return ScanResult(
      mode: ScanMode.ocr,
      rawValue: 'CUSTOM_PLUGIN_RECOGNIZED_TEXT',
      fields: {'Plugin Engine': 'MockTestPlugin v1.0'},
      isValid: true,
      confidence: 0.99,
    );
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise ScannerPro Architecture & Performance Tests', () {
    test(
      '1. Rich ScanResult returns corners, boundingBox, imageSize & scanDuration',
      () async {
        final engine = UniversalScanEngine();
        final bytes = Uint8List.fromList('https://flutter.dev'.codeUnits);
        final inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: const Size(640, 480),
            rotation:
                InputImageRotationValue.fromRawValue(0) ??
                InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: 640,
          ),
        );

        final result = await engine.processInputImage(inputImage, ScanMode.qr);

        expect(result.isValid, isTrue);
        expect(result.mode, equals(ScanMode.qr));
        expect(result.scanDuration, isNotNull);
        expect(result.imageSize, isNotNull);
        expect(result.boundingBox, isNotNull);
        expect(result.corners, isNotNull);
        expect(result.corners!.length, equals(4));

        final json = result.toJson();
        expect(json['scanDurationMs'], isNotNull);
        expect(json['boundingBox'], isNotNull);
        expect(json['corners'], isNotNull);
      },
    );

    test('2. Isolate Frame Processing & ROI Sub-region Cropping', () async {
      final rawBytes = Uint8List.fromList(
        List.generate(640 * 480, (i) => i % 256),
      );
      final task = IsolateFrameTaskData(
        bytes: rawBytes,
        width: 640,
        height: 480,
        bytesPerRow: 640,
        scanWindow: const ScanWindow(
          left: 0.2,
          top: 0.2,
          width: 0.5,
          height: 0.5,
        ),
        computeLuminosity: true,
      );

      final result = await IsolateFrameProcessor.processFrame(task);

      expect(result.croppedWidth, equals(320));
      expect(result.croppedHeight, equals(240));
      expect(result.processedBytes.length, equals(320 * 240));
      expect(result.averageLuminosity, greaterThan(0.0));
      expect(result.isLowLight, isFalse);
    });

    test('3. ScannerOptions configuration presets', () {
      const highPerf = ScannerOptions.highPerformance;
      expect(highPerf.frameThrottleMs, equals(50));
      expect(highPerf.enableDuplicateFilter, isTrue);
      expect(highPerf.enableIsolateProcessing, isTrue);

      const battery = ScannerOptions.batterySaver;
      expect(battery.scanStrategy, equals(ScanStrategy.batch));
      expect(battery.frameThrottleMs, equals(150));
    });

    test('4. ScannerPluginRegistry custom recognizer registration', () async {
      ScannerPluginRegistry.clear();
      final mockPlugin = MockTestPlugin();
      ScannerPluginRegistry.register(mockPlugin);

      expect(ScannerPluginRegistry.allPlugins.length, equals(1));
      expect(
        ScannerPluginRegistry.findForMode(ScanMode.ocr),
        equals(mockPlugin),
      );

      final engine = UniversalScanEngine();
      final inputImage = InputImage.fromFilePath('test/assets/test_sample.png');
      final result = await engine.processInputImage(inputImage, ScanMode.ocr);

      expect(mockPlugin.wasInvoked, isTrue);
      expect(result.rawValue, equals('CUSTOM_PLUGIN_RECOGNIZED_TEXT'));
      expect(result.fields['Plugin Engine'], equals('MockTestPlugin v1.0'));

      ScannerPluginRegistry.clear();
    });

    test('5. ScannerController tap-to-focus and zoom controls', () async {
      final controller = ScannerController();
      expect(controller.currentZoomLevel, equals(1.0));

      await controller.setZoomLevel(3.0);
      expect(controller.currentZoomLevel, equals(3.0));

      await controller.tapToFocus(const Offset(0.5, 0.5));
      expect(controller.lastTapFocusPoint, equals(const Offset(0.5, 0.5)));

      controller.dispose();
    });

    test('6. ScannerController Batch Scan Strategy Mode', () async {
      final controller = ScannerController(
        options: const ScannerOptions(scanStrategy: ScanStrategy.batch),
      );

      expect(controller.batchResults.isEmpty, isTrue);

      await controller.processImageFile(
        'test/assets/sample_qr.png',
        mode: ScanMode.qr,
      );
      expect(controller.batchResults.length, equals(1));

      controller.clearBatch();
      expect(controller.batchResults.isEmpty, isTrue);

      controller.dispose();
    });

    test('7. Receipt OCR Parser extracts merchant, total amount and tax', () {
      const receiptText = '''
ACME SUPERMARKET
123 MAIN STREET
DATE: 2026-08-01
ITEM 1   \$12.50
ITEM 2    \$4.99
TAX       \$1.40
TOTAL    \$18.89
THANK YOU FOR SHOPPING
''';

      final result = ReceiptParser.parse(receiptText);
      expect(result.isValid, isTrue);
      expect(result.fields['Merchant / Store'], equals('ACME SUPERMARKET'));
      expect(result.fields['Total Amount'], equals('\$18.89'));
      expect(result.fields['Tax Amount'], equals('\$1.40'));
      expect(result.fields['Receipt Date'], equals('2026-08-01'));
    });

    test(
      '8. Business Card OCR Parser extracts contact name, email and phone',
      () {
        const cardText = '''
Francis Xavier
Senior Systems Architect
TechCorp Global Ltd
Email: francis@techcorp.io
Tel: +1-555-0199
Website: www.techcorp.io
''';

        final result = BusinessCardParser.parse(cardText);
        expect(result.isValid, isTrue);
        expect(result.fields['Contact Name'], equals('Francis Xavier'));
        expect(result.fields['Email Address'], equals('francis@techcorp.io'));
        expect(result.fields['Phone Number'], equals('+1-555-0199'));
      },
    );

    test('9. DocumentScannerService & PdfExportUtil PDF exporter', () {
      final corners = DocumentScannerService.detectDocumentEdges(
        const Size(800, 600),
      );
      expect(corners.topLeft.dx, greaterThan(0.0));
      expect(corners.bottomRight.dx, lessThan(800.0));

      final sampleResult = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'https://flutter.dev',
        fields: {'Type': 'URL'},
      );

      final pdfBytes = PdfExportUtil.exportResultsToPdf(
        results: [sampleResult],
        title: 'Enterprise Test PDF',
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      expect(
        String.fromCharCodes(pdfBytes.sublist(0, 8)),
        contains('%PDF-1.4'),
      );
    });

    test('10. Telemetry ScannerStats and Scan History', () async {
      final controller = ScannerController(
        options: const ScannerOptions(
          enableScanHistory: true,
          maxHistorySize: 10,
        ),
      );

      expect(controller.scanHistory.isEmpty, isTrue);

      await controller.processBytes(
        Uint8List.fromList('https://flutter.dev'.codeUnits),
        mode: ScanMode.qr,
      );

      expect(controller.scanHistory.length, equals(1));
      expect(controller.stats, isNotNull);

      controller.clearHistory();
      expect(controller.scanHistory.isEmpty, isTrue);

      controller.dispose();
    });
  });
}
