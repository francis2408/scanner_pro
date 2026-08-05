import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileScanner & ScanbotSDK Compatibility Suite', () {
    test('MobileScannerController initialization, camera facing, torch state and lifecycle', () async {
      final controller = MobileScannerController(
        facing: CameraFacing.back,
        torchState: TorchState.off,
        autoStart: false,
      );

      expect(controller.facing, CameraFacing.back);
      expect(controller.torchState, TorchState.off);
      expect(controller.scannerController.isDisposed, false);

      await controller.start();
      expect(controller.scannerController.isPaused, false);

      await controller.stop();
      expect(controller.scannerController.isPaused, true);

      controller.dispose();
      expect(controller.scannerController.isDisposed, true);
    });

    testWidgets('MobileScanner widget renders camera preview view', (tester) async {
      final controller = MobileScannerController(autoStart: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileScanner(
              controller: controller,
              onDetect: (capture) {},
            ),
          ),
        ),
      );

      expect(find.byType(MobileScanner), findsOneWidget);
      expect(find.byType(UniversalScannerView), findsOneWidget);

      controller.dispose();
    });

    test('ScanbotSdk static facade methods', () async {
      final ocrResult = await ScanbotSdk.performOcr('TAX INVOICE #998821\nTOTAL: \$150.00');
      expect(ocrResult.isValid, true);
      expect(ocrResult.rawValue, contains('998821'));

      final barcodeResult = await ScanbotSdk.scanBarcode('https://flutter.dev');
      expect(barcodeResult.isValid, true);
      expect(barcodeResult.rawValue, 'https://flutter.dev');

      final pageBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final cropped = ScanbotSdk.applyFilterAndCrop(
        pageBytes,
        corners: const DocumentCorners(
          topLeft: Offset(10, 10),
          topRight: Offset(90, 10),
          bottomRight: Offset(90, 90),
          bottomLeft: Offset(10, 90),
        ),
        filter: DocumentFilterMode.grayscale,
      );
      expect(cropped.length, pageBytes.length);

      final pdfBytes = ScanbotSdk.createPdf(
        [
          DocumentPage(
            id: 'page_1',
            originalBytes: pageBytes,
            corners: const DocumentCorners(
              topLeft: Offset(0, 0),
              topRight: Offset(100, 0),
              bottomRight: Offset(100, 100),
              bottomLeft: Offset(0, 100),
            ),
          ),
        ],
        title: 'Scanbot Test Export',
      );
      expect(pdfBytes.isNotEmpty, true);
    });

    test('DocumentScanSession multi-page management', () {
      final session = DocumentScanSession(
        id: 'session_1',
        name: 'Invoice Scanning Session',
        maxPages: 5,
      );

      expect(session.pageCount, 0);
      expect(session.isFull, false);

      final sampleBytes = Uint8List.fromList(List.generate(200, (i) => 128));
      final p1 = session.addPage(imageBytes: sampleBytes);
      final p2 = session.addPage(imageBytes: sampleBytes, filterMode: DocumentFilterMode.magicColor);

      expect(session.pageCount, 2);
      expect(session.pages[0].id, p1.id);

      session.reorderPage(0, 1);
      expect(session.pages[0].id, p2.id);

      session.applyFilterToAll(DocumentFilterMode.binarization);
      expect(session.pages[0].filterMode, DocumentFilterMode.binarization);
      expect(session.pages[1].filterMode, DocumentFilterMode.binarization);

      final pdfBytes = session.exportToPdf();
      expect(pdfBytes.isNotEmpty, true);

      final removed = session.removePage(p1.id);
      expect(removed, true);
      expect(session.pageCount, 1);

      session.clear();
      expect(session.pageCount, 0);
    });
  });
}
