import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerController & Standalone Functionality Tests', () {
    test('ScannerController default initialization and mode switching', () {
      final controller = ScannerController(initialMode: ScanMode.passport);

      expect(controller.selectedMode, ScanMode.passport);
      expect(controller.currentMode, ScanMode.passport);
      expect(controller.isInitialized, false);
      expect(controller.isFlashOn, false);
      expect(controller.isPaused, false);

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.setMode(ScanMode.aadhaar);

      expect(controller.selectedMode, ScanMode.aadhaar);
      expect(notified, true);

      controller.pauseScanning();
      expect(controller.isPaused, true);

      controller.resumeScanning();
      expect(controller.isPaused, false);

      controller.dispose();
    });

    testWidgets('ScannerCameraPreview renders placeholder when uninitialized', (widgetTester) async {
      final controller = ScannerController(initialMode: ScanMode.qr);

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerCameraPreview(controller: controller),
          ),
        ),
      );

      expect(find.text('CAMERA PREVIEW ACTIVE'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('UniversalScannerView.builder renders custom screen design', (widgetTester) async {
      ScanResult? detectedResult;

      await widgetTester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalScannerView.builder(
              initialMode: ScanMode.pan,
              onResultDetected: (res) => detectedResult = res,
              builder: (context, controller, cameraPreview) {
                return Stack(
                  children: [
                    cameraPreview,
                    const Positioned(
                      top: 40,
                      left: 20,
                      child: Text('MY CUSTOM HEADER', style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: () => controller.setMode(ScanMode.vin),
                      child: Text('Mode: ${controller.selectedMode.title}'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('MY CUSTOM HEADER'), findsOneWidget);
      expect(find.text('Mode: PAN Card'), findsOneWidget);
      expect(detectedResult, isNull);

      await widgetTester.tap(find.byType(ElevatedButton));
      await widgetTester.pump();

      expect(find.text('Mode: VIN Number'), findsOneWidget);
    });
  });
}
