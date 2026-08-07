import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/core/engine/auto_capture_state_machine.dart';
import 'package:scannerpro/core/engine/auto_zoom_controller.dart';
import 'package:scannerpro/core/engine/barcode_decoder_engine.dart';
import 'package:scannerpro/core/engine/document_detector_engine.dart';
import 'package:scannerpro/core/engine/image_preprocessing_engine.dart';
import 'package:scannerpro/core/models/scan_result.dart';
import 'package:scannerpro/core/services/document_scanner_service.dart';

void main() {
  group('Enterprise Vision Architecture Engine Tests', () {
    test('ImagePreprocessingEngine computes Laplacian blur score and Sauvola binarization', () {
      final width = 64;
      final height = 64;
      final gray = Uint8List(width * height);

      // Create a checkerboard pattern for sharpness
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          gray[y * width + x] = ((x ~/ 4) % 2 == (y ~/ 4) % 2) ? 255 : 0;
        }
      }

      final blurScore = ImagePreprocessingEngine.computeBlurScore(gray, width, height);
      expect(blurScore, greaterThan(100.0));

      final sauvola = ImagePreprocessingEngine.sauvolaBinarize(gray, width, height);
      expect(sauvola.length, equals(width * height));

      final otsu = ImagePreprocessingEngine.otsuBinarize(gray, width, height);
      expect(otsu.length, equals(width * height));

      final result = ImagePreprocessingEngine.processFrame(gray, width, height);
      expect(result.width, equals(width));
      expect(result.height, equals(height));
      expect(result.isBlurry, isFalse);
    });

    test('DocumentDetectorEngine sorts corners and detects skew angle', () {
      final points = [
        const Offset(100, 100),
        const Offset(10, 10),
        const Offset(100, 10),
        const Offset(10, 100),
      ];

      final sorted = DocumentDetectorEngine.sortCorners(points);
      expect(sorted.topLeft, equals(const Offset(10, 10)));
      expect(sorted.topRight, equals(const Offset(100, 10)));
      expect(sorted.bottomRight, equals(const Offset(100, 100)));
      expect(sorted.bottomLeft, equals(const Offset(10, 100)));

      final skew = DocumentDetectorEngine.detectSkewAngle(sorted);
      expect(skew.abs(), lessThan(1.0));
    });

    test('AutoCaptureStateMachine transitions state and triggers capture when steady', () {
      final machine = AutoCaptureStateMachine(requiredStableFrames: 2);
      expect(machine.state, equals(AutoCaptureState.idle));

      const quad1 = DocumentCorners(
        topLeft: Offset(10, 10),
        topRight: Offset(90, 10),
        bottomRight: Offset(90, 90),
        bottomLeft: Offset(10, 90),
      );

      // Frame 1
      bool triggered = machine.processFrame(
        quad: quad1,
        blurScore: 120.0,
        isLowLight: false,
      );
      expect(triggered, isFalse);
      expect(machine.state, equals(AutoCaptureState.detecting));

      // Frame 2
      triggered = machine.processFrame(
        quad: quad1,
        blurScore: 120.0,
        isLowLight: false,
      );
      expect(triggered, isFalse);
      expect(machine.state, equals(AutoCaptureState.stabilizing));

      // Frame 3 - Should trigger auto capture
      triggered = machine.processFrame(
        quad: quad1,
        blurScore: 120.0,
        isLowLight: false,
      );
      expect(triggered, isTrue);
      expect(machine.state, equals(AutoCaptureState.captured));

      machine.reset();
      expect(machine.state, equals(AutoCaptureState.idle));
    });

    test('AutoZoomController scales zoom factor when target is small relative to ROI', () {
      final controller = AutoZoomController(minZoom: 1.0, maxZoom: 5.0);
      expect(controller.currentZoom, equals(1.0));

      const roi = Rect.fromLTWH(50, 50, 400, 400); // 160,000 px area
      const smallTarget = Rect.fromLTWH(100, 100, 40, 40); // 1,600 px area (1% of ROI)

      final newZoom = controller.evaluateTargetZoom(
        targetBoundingBox: smallTarget,
        roiScanWindow: roi,
        frameSize: const Size(640, 480),
      );

      expect(newZoom, greaterThan(1.0));
    });

    test('BarcodeDecoderEngine decodes frames and updates spatial barcode tracker', () {
      final tracker = BarcodeDecoderEngine();

      final barcode1 = BarcodeResult(
        rawValue: 'https://example.com/item1',
        format: 'QR_CODE',
        boundingBox: const Rect.fromLTWH(50, 50, 100, 100),
        corners: const [
          Offset(50, 50),
          Offset(150, 50),
          Offset(150, 150),
          Offset(50, 150),
        ],
      );

      final tracks1 = tracker.updateTracker([barcode1]);
      expect(tracks1.length, equals(1));
      expect(tracks1.first.rawValue, equals('https://example.com/item1'));
      expect(tracks1.first.hitCount, equals(1));

      // Second frame with same barcode slightly shifted
      final barcode2 = BarcodeResult(
        rawValue: 'https://example.com/item1',
        format: 'QR_CODE',
        boundingBox: const Rect.fromLTWH(52, 52, 100, 100),
        corners: const [
          Offset(52, 52),
          Offset(152, 52),
          Offset(152, 152),
          Offset(52, 152),
        ],
      );

      final tracks2 = tracker.updateTracker([barcode2]);
      expect(tracks2.length, equals(1));
      expect(tracks2.first.hitCount, equals(2));
      expect(tracks2.first.id, equals(tracks1.first.id));
    });
  });
}
