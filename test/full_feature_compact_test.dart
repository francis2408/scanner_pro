import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Full Feature & Compact API Verification Suite', () {
    late ScannerController controller;

    setUp(() {
      controller = ScannerController(
        options: ScannerOptions.custom(
          allowDuplicates: false,
          duplicateDelay: const Duration(seconds: 3),
          scanArea: const Rect.fromLTWH(10, 20, 200, 150),
          scanStrategy: ScanStrategy.continuous,
          enableScanHistory: true,
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('1. Multi Barcode Detection and BarcodeResult model', () async {
      final engine = UniversalScanEngine();
      final result = await engine.processBytes(
        Uint8List.fromList([0, 1, 2, 3]),
        ScanMode.multiCode,
      );

      expect(result.barcodes, isNotEmpty);

      final barcode = result.barcodes.first;
      expect(barcode.rawValue, isNotEmpty);
      expect(barcode.format, isNotEmpty);
      expect(barcode.toJson(), contains('format'));
      expect(barcode.toString(), contains('BarcodeResult'));
    });

    test('2. Scan Region (ROI) & ScanArea Options', () {
      final options = ScannerOptions.custom(
        scanArea: const Rect.fromLTWH(15, 25, 300, 200),
      );

      expect(options.scanArea, equals(const Rect.fromLTWH(15, 25, 300, 200)));
      expect(options.rectScanArea, equals(const Rect.fromLTWH(15, 25, 300, 200)));

      final window = ScanWindow(left: 0.1, top: 0.1, width: 0.8, height: 0.8);
      final pixelRect = window.toPixelRect(const Size(1000, 1000));
      expect(pixelRect, equals(const Rect.fromLTWH(100, 100, 800, 800)));
    });

    test('3. Torch & Luminosity Controls', () async {
      expect(controller.torchLevel, equals(1.0));
      await controller.setTorchBrightness(0.5);
      expect(controller.torchLevel, equals(0.5));

      expect(controller.isLowLight, isFalse);
      expect(controller.onLowLightStateChanged, isA<Stream<bool>>());
    });

    test('4. Duplicate Detection Options Aliases', () {
      final opts = ScannerOptions.custom(
        allowDuplicates: false,
        duplicateDelay: const Duration(seconds: 3),
      );

      expect(opts.allowDuplicates, isFalse);
      expect(opts.enableDuplicateFilter, isTrue);
      expect(opts.duplicateDelay, equals(const Duration(seconds: 3)));
      expect(opts.duplicateTimeout, equals(const Duration(seconds: 3)));
    });

    test('5. Continuous, Single, and Batch Strategy Switching', () {
      expect(controller.options.scanStrategy, equals(ScanStrategy.continuous));

      final batchOpts = ScannerOptions(scanStrategy: ScanStrategy.batch);
      expect(batchOpts.scanStrategy, equals(ScanStrategy.batch));

      final singleOpts = ScannerOptions(scanStrategy: ScanStrategy.single);
      expect(singleOpts.scanStrategy, equals(ScanStrategy.single));
    });

    test('6. ScanHistoryController CRUD & Export', () async {
      final history = controller.historyController;
      expect(history.isEmpty, isTrue);

      final result1 = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'https://flutter.dev',
        fields: {'URL': 'https://flutter.dev'},
      );

      final result2 = ScanResult(
        mode: ScanMode.barcode,
        rawValue: '123456789012',
        fields: {'UPC': '123456789012'},
      );

      history.add(result1);
      history.add(result2);

      expect(history.length, equals(2));
      expect(history.history.first.rawValue, equals('123456789012'));

      final filtered = history.filterByMode(ScanMode.qr);
      expect(filtered.length, equals(1));
      expect(filtered.first.rawValue, equals('https://flutter.dev'));

      final searchRes = history.search('flutter');
      expect(searchRes.length, equals(1));

      final jsonStr = history.exportToJson();
      expect(jsonStr, contains('flutter.dev'));

      final csvStr = history.exportToCsv();
      expect(csvStr, contains('Raw Value'));
      expect(csvStr, contains('flutter.dev'));

      final pdfBytes = await history.exportToPdf();
      expect(pdfBytes, isNotEmpty);

      history.removeAt(0);
      expect(history.length, equals(1));

      history.clear();
      expect(history.isEmpty, isTrue);
    });

    test('7. Enhanced Performance Telemetry Metrics', () {
      final stats = ScannerStats(
        fps: 29.5,
        processingTimeMs: 14.2,
        memoryMb: 42.8,
        droppedFrames: 2,
        processedFrames: 120,
      );

      expect(stats.detectionTimeMs, equals(14.2));
      expect(stats.averageScanTimeMs, equals(14.2));
      expect(stats.memoryUsageMB, equals(42.8));
      expect(stats.memoryUsageBytes, greaterThan(40 * 1024 * 1024));
      expect(stats.toJson(), contains('processingTimeMs'));
    });

    test('8. Camera Controls & Pinch Zoom', () async {
      expect(controller.currentZoomLevel, equals(1.0));

      await controller.setZoomLevel(2.5);
      expect(controller.currentZoomLevel, equals(2.5));

      await controller.pinchZoom(1.2);
      expect(controller.currentZoomLevel, equals(3.0));

      await controller.setAutofocus(true);
      expect(controller.isFocusLocked, isFalse);

      await controller.setExposureOffset(0.5);
    });

    test('9. Image, Bytes, and Asset Scanner APIs', () async {
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final resBytes = await controller.scanBytes(testBytes, mode: ScanMode.qr);
      expect(resBytes, isNotNull);
      expect(resBytes.mode, equals(ScanMode.qr));

      final resAsset = await controller.scanAsset('assets/test.png', mode: ScanMode.barcode);
      expect(resAsset, isNotNull);
      expect(resAsset.mode, equals(ScanMode.barcode));
    });

    testWidgets('10. UniversalScannerView Overlay & Customization', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalScannerView(
              initialMode: ScanMode.qr,
              primaryAccentColor: Colors.deepPurple,
              overlayMaskColor: Colors.black54,
              showLaserBeam: true,
              overlayBuilder: (context, ctrl) {
                return const Center(
                  child: Text('Custom Scanner Overlay'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Custom Scanner Overlay'), findsOneWidget);
    });
  });
}
