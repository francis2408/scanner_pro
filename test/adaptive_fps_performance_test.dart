import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  group('Adaptive FPS State Machine & Performance Optimization Tests', () {
    test('1. ScannerFpsState exposes correct target FPS and frame intervals', () {
      expect(ScannerFpsState.searching.targetFps, equals(30));
      expect(ScannerFpsState.searching.frameIntervalMs, equals(33));

      expect(ScannerFpsState.detected.targetFps, equals(15));
      expect(ScannerFpsState.detected.frameIntervalMs, equals(66));

      expect(ScannerFpsState.idle.targetFps, equals(10));
      expect(ScannerFpsState.idle.frameIntervalMs, equals(100));
    });

    test('2. IsolateFrameProcessor Pooled Buffer recycles byte array allocations', () {
      final buf1 = IsolateFrameProcessor.getPooledBuffer(1024);
      expect(buf1.length, greaterThanOrEqualTo(1024));

      final buf2 = IsolateFrameProcessor.getPooledBuffer(512);
      // Same pooled buffer instance is reused
      expect(identical(buf1, buf2), isTrue);
    });

    test('3. ScannerOptions supports new performance parameters', () {
      const options = ScannerOptions(
        enableAdaptiveFps: true,
        enableProgressiveResolution: true,
        enableDetectionCache: true,
        duplicateTimeout: Duration(milliseconds: 2000),
        frameQueueCapacity: 3,
      );

      expect(options.enableAdaptiveFps, isTrue);
      expect(options.enableProgressiveResolution, isTrue);
      expect(options.enableDetectionCache, isTrue);
      expect(options.duplicateTimeout.inMilliseconds, equals(2000));
      expect(options.frameQueueCapacity, equals(3));
    });
  });
}
