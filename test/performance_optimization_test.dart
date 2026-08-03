import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerPro 1.2.0 Performance & Optimization Suite', () {
    test('IsolateFrameProcessor performs ROI sub-region cropping correctly', () async {
      // 10x10 dummy gray byte buffer (100 bytes)
      final bytes = Uint8List.fromList(List.generate(100, (i) => i % 255));
      final task = IsolateFrameTaskData(
        bytes: bytes,
        width: 10,
        height: 10,
        bytesPerRow: 10,
        scanWindow: ScanWindow(left: 0.2, top: 0.2, width: 0.5, height: 0.5),
        computeLuminosity: true,
        enableEnhancement: false,
        enableBlurDetection: false,
      );

      final result = await IsolateFrameProcessor.processFrame(task);

      expect(result.croppedWidth, equals(5));
      expect(result.croppedHeight, equals(5));
      expect(result.processedBytes.length, equals(25));
      expect(result.averageLuminosity, greaterThanOrEqualTo(0.0));
      expect(result.enhancementsApplied, contains('ROI Crop (5x5)'));
    });

    test('IsolateFrameProcessor detects frame blur accurately', () async {
      // Uniform flat gray image (blurry/out of focus, Laplacian variance ~ 0)
      final flatBytes = Uint8List.fromList(List.filled(400, 128));
      final task = IsolateFrameTaskData(
        bytes: flatBytes,
        width: 20,
        height: 20,
        bytesPerRow: 20,
        computeLuminosity: false,
        enableEnhancement: false,
        enableBlurDetection: true,
      );

      final result = await IsolateFrameProcessor.processFrame(task);

      expect(result.isBlurry, isTrue);
      expect(result.blurScore, lessThan(25.0));
    });

    test('IsolateFrameProcessor applies image enhancement and contrast stretching', () async {
      // Compressed dynamic range byte buffer (values between 100 and 120)
      final compressedBytes = Uint8List.fromList(List.generate(400, (i) => 100 + (i % 20)));
      final task2 = IsolateFrameTaskData(
        bytes: compressedBytes,
        width: 20,
        height: 20,
        bytesPerRow: 20,
        computeLuminosity: true,
        enableEnhancement: true,
        enableBlurDetection: false,
      );

      final result2 = await IsolateFrameProcessor.processFrame(task2);

      expect(result2.enhancementsApplied.any((e) => e.contains('Contrast Stretch')), isTrue);
      expect(result2.contrastScore, greaterThan(0.0));
    });

    test('IsolateFrameProcessor reuses pooled buffers effectively', () {
      final buf1 = IsolateFrameProcessor.getPooledBuffer(1024);
      final buf2 = IsolateFrameProcessor.getPooledBuffer(1024);
      expect(buf1.length, greaterThanOrEqualTo(1024));
      expect(identical(buf1, buf2), isTrue);
    });

    test('Enriched ScanResult models serialize enterprise metadata correctly', () {
      final now = DateTime.now();
      final result = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'https://flutter.dev',
        fields: {'Value Type': 'WEB URL', 'URL Link': 'https://flutter.dev'},
        format: 'QR_CODE',
        confidence: 0.99,
        rawBytes: Uint8List.fromList([1, 2, 3, 4]),
        roi: const Rect.fromLTWH(10, 20, 100, 200),
        enhancementsApplied: ['Contrast Stretch', 'ROI Crop'],
        isDuplicate: false,
        timestamp: now,
      );

      final json = result.toJson();

      expect(json['mode'], equals('qr'));
      expect(json['format'], equals('QR_CODE'));
      expect(json['enhancementsApplied'], contains('Contrast Stretch'));
      expect(json['roi']['left'], equals(10.0));
      expect(json['roi']['top'], equals(20.0));
      expect(json['isDuplicate'], isFalse);

      final copied = result.copyWith(isDuplicate: true);
      expect(copied.isDuplicate, isTrue);
      expect(copied.format, equals('QR_CODE'));
    });

    test('ScannerOptions presets configure performance parameters properly', () {
      const highPerf = ScannerOptions.highPerformance;
      expect(highPerf.targetFrameRate, equals(20));
      expect(highPerf.enableIsolateProcessing, isTrue);
      expect(highPerf.enableImageEnhancement, isTrue);
      expect(highPerf.enableBlurDetection, isTrue);
      expect(highPerf.enableAutoZoom, isTrue);

      const batSaver = ScannerOptions.batterySaver;
      expect(batSaver.targetFrameRate, equals(10));
      expect(batSaver.enableImageEnhancement, isFalse);
      expect(batSaver.enableBlurDetection, isFalse);
      expect(batSaver.scanStrategy, equals(ScanStrategy.batch));
    });

    test('ScannerController static prewarm helper executes without exceptions', () async {
      await ScannerController.prewarm();
      expect(true, isTrue);
    });
  });
}
