import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  group('ScannerPro v2.4.0 Enterprise Suite Tests', () {
    // -------------------------------------------------------------------------
    // 1. ImageCompressor Tests
    // -------------------------------------------------------------------------
    group('ImageCompressor', () {
      test('compress reduces size with low quality factor', () {
        final sample = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final result = ImageCompressor.compress(sample, quality: 0.5);

        expect(result.originalSize, equals(1000));
        expect(result.compressedSize, lessThanOrEqualTo(result.originalSize));
        expect(result.qualityUsed, equals(0.5));
        expect(result.summary, contains('Compressed'));
      });

      test('compressWithPreset applies preset quality factors correctly', () {
        final sample = Uint8List.fromList(List.generate(500, (i) => i % 256));
        final resultHigh = ImageCompressor.compressWithPreset(
            sample, CompressionPreset.high);
        final resultLow = ImageCompressor.compressWithPreset(
            sample, CompressionPreset.low);

        expect(resultHigh.qualityUsed, equals(0.85));
        expect(resultLow.qualityUsed, equals(0.50));
      });

      test('batchCompress processes multiple image byte buffers', () {
        final sample1 = Uint8List.fromList(List.generate(200, (i) => i % 256));
        final sample2 = Uint8List.fromList(List.generate(300, (i) => (i * 2) % 256));

        final results = ImageCompressor.batchCompress([sample1, sample2], quality: 0.6);
        expect(results.length, equals(2));
        expect(results[0].originalSize, equals(200));
        expect(results[1].originalSize, equals(300));
      });

      test('estimateCompressedSize provides reasonable approximation', () {
        final estimated = ImageCompressor.estimateCompressedSize(10000, quality: 0.5);
        expect(estimated, lessThan(10000));
        expect(estimated, greaterThan(0));
      });

      test('downsample reduces dimensions by factor', () {
        final bytes = Uint8List.fromList(List.generate(100, (i) => i));
        final downsampled = ImageCompressor.downsample(
          bytes,
          width: 10,
          height: 10,
          factor: 2,
        );
        expect(downsampled.length, equals(25)); // 5x5
      });
    });

    // -------------------------------------------------------------------------
    // 2. EncryptedStorage Tests
    // -------------------------------------------------------------------------
    group('EncryptedStorage', () {
      test('encrypt and decrypt round-trip produces identical ScanResult', () {
        final original = ScanResult(
          mode: ScanMode.qr,
          rawValue: 'https://scannerpro.dev',
          fields: {'URL': 'https://scannerpro.dev'},
          confidence: 0.98,
        );

        final encrypted = EncryptedStorage.encrypt(original, password: 'secret_password_123');
        expect(encrypted.ciphertext.isNotEmpty, isTrue);
        expect(encrypted.modeHint, equals('qr'));

        final decrypted = EncryptedStorage.decrypt(encrypted, password: 'secret_password_123');
        expect(decrypted, isNotNull);
        expect(decrypted!.rawValue, equals(original.rawValue));
        expect(decrypted.mode, equals(original.mode));
      });

      test('decrypt throws EncryptionException on wrong password', () {
        final original = ScanResult(
          mode: ScanMode.barcode,
          rawValue: '1234567890123',
          fields: {'Format': 'EAN_13'},
        );

        final encrypted = EncryptedStorage.encrypt(original, password: 'correct_password');
        expect(
          () => EncryptedStorage.decrypt(encrypted, password: 'wrong_password'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('validatePassword correctly checks password validity', () {
        final original = ScanResult(mode: ScanMode.ocr, rawValue: 'Sample OCR text');
        final encrypted = EncryptedStorage.encrypt(original, password: 'my_pass');

        expect(EncryptedStorage.validatePassword(encrypted, password: 'my_pass'), isTrue);
        expect(EncryptedStorage.validatePassword(encrypted, password: 'invalid'), isFalse);
      });

      test('encryptBatch and decryptBatch handles multiple scan results', () {
        final item1 = ScanResult(mode: ScanMode.qr, rawValue: 'Item 1');
        final item2 = ScanResult(mode: ScanMode.barcode, rawValue: 'Item 2');

        final encrypted = EncryptedStorage.encryptBatch([item1, item2], password: 'batch_pass');
        final decrypted = EncryptedStorage.decryptBatch(encrypted, password: 'batch_pass');

        expect(decrypted, isNotNull);
        expect(decrypted!.length, equals(2));
        expect(decrypted[0].rawValue, equals('Item 1'));
        expect(decrypted[1].rawValue, equals('Item 2'));
      });

      test('EncryptedScanData JSON serialization round-trip', () {
        final original = ScanResult(mode: ScanMode.passport, rawValue: 'P<IND12345');
        final encrypted = EncryptedStorage.encrypt(original, password: 'pass');

        final jsonStr = encrypted.toJsonString();
        final reconstructed = EncryptedScanData.fromJsonString(jsonStr);

        expect(reconstructed.ciphertext, equals(encrypted.ciphertext));
        expect(reconstructed.iv, equals(encrypted.iv));
        expect(reconstructed.salt, equals(encrypted.salt));
      });
    });

    // -------------------------------------------------------------------------
    // 3. ScanQualityAnalyzer Tests
    // -------------------------------------------------------------------------
    group('ScanQualityAnalyzer', () {
      test('analyze provides complete quality report for image bytes', () {
        final bytes = Uint8List.fromList(List.generate(640 * 480, (i) => (i % 256)));
        final report = ScanQualityAnalyzer.analyze(bytes, width: 640, height: 480);

        expect(report.grade, isNotNull);
        expect(report.overallScore, greaterThanOrEqualTo(0.0));
        expect(report.overallScore, lessThanOrEqualTo(1.0));
        expect(report.recommendations.isNotEmpty, isTrue);
      });

      test('analyzeBlur identifies blur level correctly', () {
        final uniformBytes = Uint8List.fromList(List.filled(100 * 100, 128));
        final blurResult = ScanQualityAnalyzer.analyzeBlur(uniformBytes, width: 100, height: 100);

        expect(blurResult.severity, equals(BlurSeverity.heavy));
        expect(blurResult.isSharp, isFalse);
      });

      test('analyzeLight detects low light and recommends torch', () {
        final darkBytes = Uint8List.fromList(List.filled(100 * 100, 10)); // dark pixels
        final lightResult = ScanQualityAnalyzer.analyzeLight(darkBytes);

        expect(lightResult.condition, equals(LightCondition.tooLow));
        expect(lightResult.torchRecommended, isTrue);
      });

      test('analyzeContrast computes dynamic range and ratio', () {
        final bytes = Uint8List.fromList([
          ...List.filled(500, 10),
          ...List.filled(500, 240),
        ]);
        final contrastResult = ScanQualityAnalyzer.analyzeContrast(bytes);

        expect(contrastResult.dynamicRange, equals(230));
        expect(contrastResult.isAdequate, isTrue);
      });

      test('QualityGrade letter grades map correctly', () {
        expect(QualityGrade.excellent.letterGrade, equals('A'));
        expect(QualityGrade.good.letterGrade, equals('B'));
        expect(QualityGrade.acceptable.letterGrade, equals('C'));
        expect(QualityGrade.poor.letterGrade, equals('D'));
        expect(QualityGrade.unusable.letterGrade, equals('F'));
      });
    });

    // -------------------------------------------------------------------------
    // 4. MultiScanSession Tests
    // -------------------------------------------------------------------------
    group('MultiScanSession', () {
      test('lifecycle transitions through start, pause, resume, complete', () {
        final session = MultiScanSession(name: 'Inventory Session 1');
        expect(session.state, equals(SessionState.idle));

        session.start();
        expect(session.isActive, isTrue);

        session.pause();
        expect(session.isPaused, isTrue);

        session.resume();
        expect(session.isActive, isTrue);

        session.complete();
        expect(session.isCompleted, isTrue);
      });

      test('addResult filters duplicates when enabled', () {
        final session = MultiScanSession(enableDuplicateFilter: true);
        session.start();

        final item1 = ScanResult(mode: ScanMode.qr, rawValue: 'ABC-123');
        final item2 = ScanResult(mode: ScanMode.qr, rawValue: 'ABC-123'); // Duplicate

        final added1 = session.addResult(item1);
        final added2 = session.addResult(item2);

        expect(added1, isTrue);
        expect(added2, isFalse);
        expect(session.itemCount, equals(1));
        expect(session.getStats().duplicatesFiltered, equals(1));
      });

      test('session capacity limit (maxItems) is respected', () {
        final session = MultiScanSession(maxItems: 2);
        session.start();

        session.addResult(ScanResult(mode: ScanMode.qr, rawValue: 'Code 1'));
        session.addResult(ScanResult(mode: ScanMode.qr, rawValue: 'Code 2'));
        final added3 = session.addResult(ScanResult(mode: ScanMode.qr, rawValue: 'Code 3'));

        expect(added3, isFalse);
        expect(session.itemCount, equals(2));
        expect(session.isFull, isTrue);
      });

      test('getStats calculates duration and success rates correctly', () {
        final session = MultiScanSession();
        session.start();

        session.addResult(ScanResult(mode: ScanMode.qr, rawValue: 'Valid', isValid: true));
        session.addResult(ScanResult(mode: ScanMode.barcode, rawValue: 'Invalid', isValid: false));

        final stats = session.getStats();
        expect(stats.totalScans, equals(2));
        expect(stats.validScans, equals(1));
        expect(stats.invalidScans, equals(1));
        expect(stats.successRate, equals(0.5));
      });

      test('exportToJson and exportToPdf generate valid outputs', () {
        final session = MultiScanSession(name: 'Export Test');
        session.start();
        session.addResult(ScanResult(mode: ScanMode.qr, rawValue: 'Test Payload'));

        final jsonOutput = session.exportToJson();
        expect(jsonOutput, contains('Test Payload'));

        final pdfBytes = session.exportToPdf();
        expect(pdfBytes.isNotEmpty, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 5. CloudSyncHelper Tests
    // -------------------------------------------------------------------------
    group('CloudSyncHelper', () {
      test('enqueue items creates pending sync events', () {
        final adapter = HttpCloudSyncAdapter(baseUrl: 'https://api.scannerpro.dev/sync');
        final helper = CloudSyncHelper(adapter: adapter);

        helper.enqueue(ScanResult(mode: ScanMode.qr, rawValue: 'Cloud Sync Item'));
        expect(helper.queueLength, equals(1));
        expect(helper.queueStats.pending, equals(1));
      });

      test('processQueue attempts upload for pending items', () async {
        final adapter = HttpCloudSyncAdapter(baseUrl: 'https://api.scannerpro.dev/sync');
        final helper = CloudSyncHelper(adapter: adapter);

        helper.enqueue(ScanResult(mode: ScanMode.qr, rawValue: 'Item A'));
        final count = await helper.processQueue();

        expect(count, equals(1));
        expect(helper.queueStats.synced, equals(1));
      });

      test('exportQueueState produces valid JSON representation', () {
        final adapter = HttpCloudSyncAdapter(baseUrl: 'https://api.scannerpro.dev/sync');
        final helper = CloudSyncHelper(adapter: adapter);

        helper.enqueue(ScanResult(mode: ScanMode.qr, rawValue: 'Export Queue Item'));
        final stateJson = helper.exportQueueState();

        expect(stateJson, contains('Export Queue Item'));
        expect(stateJson, contains('pending'));
      });
    });

    // -------------------------------------------------------------------------
    // 6. ScanWatermark Tests
    // -------------------------------------------------------------------------
    group('ScanWatermark', () {
      test('apply adds watermark to image byte buffer', () {
        final imageBytes = Uint8List.fromList(List.filled(200 * 200, 200));
        final config = WatermarkConfig(text: 'SAMPLE', position: WatermarkPosition.center);

        final result = ScanWatermark.apply(imageBytes, width: 200, height: 200, config: config);
        expect(result.success, isTrue);
        expect(result.watermarkedBytes.length, equals(imageBytes.length));
      });

      test('WatermarkConfig presets initialize with correct defaults', () {
        final conf = WatermarkConfig.confidential();
        final draft = WatermarkConfig.draft();
        final timestamp = WatermarkConfig.timestamp();

        expect(conf.text, equals('CONFIDENTIAL'));
        expect(draft.text, equals('DRAFT'));
        expect(timestamp.text, contains('-'));
      });

      test('generatePdfWatermarkStream returns PDF stream commands', () {
        final streamStr = ScanWatermark.generatePdfWatermarkStream('CONFIDENTIAL PDF');
        expect(streamStr, contains('CONFIDENTIAL PDF'));
        expect(streamStr, contains('/F1'));
      });
    });

    // -------------------------------------------------------------------------
    // 7. ScannerPro Facade v2.4.0 Static APIs
    // -------------------------------------------------------------------------
    group('ScannerPro Facade v2.4.0 Static APIs', () {
      test('version constant returns 2.5.0', () {
        expect(ScannerPro.version, equals('2.5.0'));
        expect(scannerProVersion, equals('2.5.0'));
      });

      test('compressImage static helper returns CompressionResult', () {
        final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
        final result = ScannerPro.compressImage(bytes, quality: 0.7);

        expect(result.compressedBytes.isNotEmpty, isTrue);
        expect(result.qualityUsed, equals(0.7));
      });

      test('encryptScan and decryptScan static helpers round-trip', () {
        final result = ScanResult(mode: ScanMode.qr, rawValue: 'Facade Encrypt Test');
        final encrypted = ScannerPro.encryptScan(result, password: 'facade_pass');
        final decrypted = ScannerPro.decryptScan(encrypted, password: 'facade_pass');

        expect(decrypted, isNotNull);
        expect(decrypted!.rawValue, equals('Facade Encrypt Test'));
      });

      test('exportToJpgBytes and exportToPngBytes generate formatted buffers', () {
        final result = ScanResult(mode: ScanMode.barcode, rawValue: '123456');
        final jpgBytes = ScannerPro.exportToJpgBytes(result);
        final pngBytes = ScannerPro.exportToPngBytes(result);

        expect(jpgBytes.length, greaterThan(0));
        expect(pngBytes.length, greaterThan(0));
        expect(jpgBytes[0], equals(0xFF)); // JPEG marker
        expect(pngBytes[0], equals(0x89)); // PNG marker
      });

      test('batchExportToPdf combines multiple scan results', () {
        final r1 = ScanResult(mode: ScanMode.qr, rawValue: 'Batch Item 1');
        final r2 = ScanResult(mode: ScanMode.barcode, rawValue: 'Batch Item 2');

        final pdfBytes = ScannerPro.batchExportToPdf(
          results: [r1, r2],
          title: 'Batch Report',
          watermarkText: 'CONFIDENTIAL',
        );

        expect(pdfBytes.length, greaterThan(0));
      });
    });

    // -------------------------------------------------------------------------
    // 8. New ScanModes (idCard & licensePlate)
    // -------------------------------------------------------------------------
    group('New ScanModes (idCard & licensePlate)', () {
      test('ScanMode.idCard provides correct UI metadata', () {
        const mode = ScanMode.idCard;
        expect(mode.title, equals('ID Card'));
        expect(mode.category, equals('ID & Cards'));
        expect(mode.targetAspectRatio, equals(1.58));
      });

      test('ScanMode.licensePlate provides correct UI metadata', () {
        const mode = ScanMode.licensePlate;
        expect(mode.title, equals('License Plate'));
        expect(mode.category, equals('Automotive'));
        expect(mode.targetAspectRatio, equals(3.0));
      });
    });

    // -------------------------------------------------------------------------
    // 9. Symmetric JSON Deserialization Tests
    // -------------------------------------------------------------------------
    group('Symmetric JSON Deserialization', () {
      test('ScanResult.fromJson reconstructs full result object', () {
        final original = ScanResult(
          mode: ScanMode.licensePlate,
          rawValue: 'ABC-1234',
          fields: {'Plate Number': 'ABC-1234'},
          isValid: true,
          confidence: 0.96,
          sessionId: 'session_999',
          exportFormat: 'pdf',
          encryptionStatus: 'encrypted',
          watermarkApplied: true,
        );

        final jsonMap = original.toJson();
        final reconstructed = ScanResult.fromJson(jsonMap);

        expect(reconstructed.mode, equals(ScanMode.licensePlate));
        expect(reconstructed.rawValue, equals('ABC-1234'));
        expect(reconstructed.sessionId, equals('session_999'));
        expect(reconstructed.exportFormat, equals('pdf'));
        expect(reconstructed.encryptionStatus, equals('encrypted'));
        expect(reconstructed.watermarkApplied, isTrue);
      });

      test('ScanQualityReport.fromJson reconstructs report object', () {
        final bytes = Uint8List.fromList(List.generate(200 * 200, (i) => i % 256));
        final report = ScanQualityAnalyzer.analyze(bytes, width: 200, height: 200);

        final jsonMap = report.toJson();
        final reconstructed = ScanQualityReport.fromJson(jsonMap);

        expect(reconstructed.grade.letterGrade, equals(report.grade.letterGrade));
        expect(reconstructed.overallScore, equals(report.overallScore));
        expect(reconstructed.blur.severity, equals(report.blur.severity));
        expect(reconstructed.light.condition, equals(report.light.condition));
      });
    });
  });
}
