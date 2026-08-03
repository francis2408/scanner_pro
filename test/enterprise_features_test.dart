import 'dart:typed_data';

import 'package:camera/camera.dart' show ResolutionPreset;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerPro Enterprise Feature & API Suite Verification', () {
    late ScannerController controller;

    setUp(() {
      controller = ScannerController(
        initialMode: ScanMode.qr,
        options: ScannerOptions(
          scanStrategy: ScanStrategy.continuous,
          rectScanArea: const Rect.fromLTWH(50, 50, 200, 200),
          allowedFormats: const ['QR_CODE', 'BARCODE', 'PDF417'],
          enableSound: false,
          enableVibration: false,
          duplicateTimeout: const Duration(milliseconds: 1500),
        ),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test(
      '1. ScannerOptions Enterprise RectScanArea & AllowedFormats Configuration',
      () {
        expect(
          controller.options.rectScanArea,
          equals(const Rect.fromLTWH(50, 50, 200, 200)),
        );
        expect(controller.options.allowedFormats, contains('QR_CODE'));
        expect(controller.options.enableSound, isFalse);
        expect(controller.options.enableVibration, isFalse);
        expect(
          controller.options.duplicateTimeout.inMilliseconds,
          equals(1500),
        );
      },
    );

    test(
      '2. Camera Controls Focus Locking, Torch Level & Resolution Switching',
      () async {
        expect(controller.isFocusLocked, isFalse);
        await controller.lockFocus();
        expect(controller.isFocusLocked, isTrue);

        await controller.unlockFocus();
        expect(controller.isFocusLocked, isFalse);

        await controller.setTorchLevel(0.8);
        expect(controller.torchLevel, equals(0.8));

        expect(controller.resolutionPreset, equals(ResolutionPreset.high));
      },
    );

    test('3. Multi-Barcode Detection & scanAll API Verification', () async {
      final engine = UniversalScanEngine();

      final sampleBytes = Uint8List.fromList(
        'QR1\n---\nQR2\n---\nQR3'.codeUnits,
      );
      final result = await engine.processBytes(sampleBytes, ScanMode.multiCode);

      expect(result.isValid, isTrue);
      expect(result.multiResults, isNotNull);
      expect(result.multiResults!.length, equals(3));
      expect(result.multiResults![0].rawValue, equals('QR1'));
      expect(result.multiResults![1].rawValue, equals('QR2'));
      expect(result.multiResults![2].rawValue, equals('QR3'));
    });

    test('4. Raw Bytes and Image Memory Processing', () async {
      final sampleBytes = Uint8List.fromList('https://flutter.dev'.codeUnits);
      final result = await controller.processBytes(
        sampleBytes,
        mode: ScanMode.qr,
      );

      expect(result.isValid, isTrue);
      expect(result.rawValue, equals('https://flutter.dev'));
      expect(result.format, equals('QR_CODE'));
      expect(controller.lastResult, equals(result));
    });

    test('5. Duplicate Payload Filtering Window', () async {
      final bytes = Uint8List.fromList('DUP_PAYLOAD_123'.codeUnits);

      int emitCount = 0;
      controller.onResult.listen((res) {
        emitCount++;
      });

      await controller.processBytes(bytes, mode: ScanMode.qr);
      await controller.processBytes(bytes, mode: ScanMode.qr); // duplicate
      await controller.processBytes(bytes, mode: ScanMode.qr); // duplicate

      expect(emitCount, equals(1));
      expect(controller.scanHistory.length, equals(1));
    });

    test('6. Enterprise Analytics Tracking', () async {
      expect(controller.analytics.totalScans, equals(0));

      final bytes1 = Uint8List.fromList('ITEM_001'.codeUnits);
      await controller.processBytes(bytes1, mode: ScanMode.barcode);

      expect(controller.analytics.totalScans, equals(1));
      expect(controller.analytics.successfulScans, equals(1));
      expect(controller.analytics.successRate, equals(100.0));
      expect(controller.analytics.scansByMode['barcode'], equals(1));
    });

    test('7. CSV, JSON, and PDF Export Utilities', () {
      final res1 = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'INV_1001',
        fields: {'Product': 'Widget A', 'Price': '\$10.00'},
        format: 'QR_CODE',
      );
      final res2 = ScanResult(
        mode: ScanMode.barcode,
        rawValue: '5449000000996',
        fields: {'Country': 'Belgium'},
        format: 'EAN_13',
      );

      final csv = CsvExporter.exportToCsv([res1, res2]);
      expect(csv, contains('INV_1001'));
      expect(csv, contains('5449000000996'));
      expect(csv, contains('QR_CODE'));

      final json = JsonExporter.exportToJson([res1, res2]);
      expect(json, contains('INV_1001'));
      expect(json, contains('5449000000996'));

      final pdfBytes = PdfExportUtil.exportResultsToPdf(results: [res1, res2]);
      expect(pdfBytes.length, greaterThan(100));
    });

    test('8. Micro-Benchmark Suite Execution', () async {
      final engine = UniversalScanEngine();
      final sampleBytes = Uint8List.fromList(
        'BENCHMARK_PAYLOAD_TEST'.codeUnits,
      );

      final benchmark = await ScannerBenchmark.runVisionEngineBenchmark(
        engine: engine,
        sampleBytes: sampleBytes,
        mode: ScanMode.qr,
        runs: 50,
      );

      expect(benchmark.totalRuns, equals(50));
      expect(benchmark.opsPerSecond, greaterThan(0));
      expect(benchmark.toString(), contains('BENCHMARK'));
    });

    test(
      '9. Document Quality Scoring & Isolate Preprocessing Verification',
      () async {
        final sampleBytes = Uint8List(640 * 480);
        for (int i = 0; i < sampleBytes.length; i++) {
          sampleBytes[i] = (i % 256);
        }

        final taskData = IsolateFrameTaskData(
          bytes: sampleBytes,
          width: 640,
          height: 480,
          bytesPerRow: 640,
          computeLuminosity: true,
          enableEnhancement: true,
          enableBlurDetection: true,
        );

        final result = await IsolateFrameProcessor.processFrame(taskData);
        expect(result.qualityScore, isNotNull);
        expect(result.qualityScore.blurScore, greaterThan(0));
        expect(result.qualityScore.brightnessScore, greaterThanOrEqualTo(0.0));
        expect(result.qualityScore.overallQuality, greaterThan(0.0));
      },
    );

    test(
      '10. Multi-Frame Consensus Voting Engine for 98-99% Accuracy Target',
      () async {
        final consensusController = ScannerController(
          options: const ScannerOptions(
            enableMultiFrameConsensus: true,
            consensusFrameCount: 3,
            consensusAccuracyThreshold: 0.98,
            duplicateTimeout: Duration(milliseconds: 10),
          ),
        );

        final payloadBytes = Uint8List.fromList(
          'HIGH_ACCURACY_PAYLOAD_99'.codeUnits,
        );

        int emitCount = 0;
        double lastConfidence = 0.0;
        consensusController.onResult.listen((res) {
          emitCount++;
          lastConfidence = res.confidence;
        });

        // Send 3 identical frames to achieve 3/3 consensus
        await consensusController.processBytes(payloadBytes, mode: ScanMode.qr);
        await consensusController.processBytes(payloadBytes, mode: ScanMode.qr);
        await consensusController.processBytes(payloadBytes, mode: ScanMode.qr);

        expect(emitCount, equals(1));
        expect(lastConfidence, greaterThanOrEqualTo(0.98));

        consensusController.dispose();
      },
    );
  });
}
