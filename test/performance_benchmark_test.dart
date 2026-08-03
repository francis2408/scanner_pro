import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  group('ScannerPro Performance & Benchmark Analysis Suite', () {
    test('Passport MRZ Parser High-Throughput Performance Benchmark (1,000 runs)', () {
      const sampleMrz =
          'P<USADICKSON<<BENJAMIN<FRANKLIN<<<<<<<<<<<<<\n1234567897USA8501019M3001019<<<<<<<<<<<<<<04';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = MrzPassportParser.parse(sampleMrz);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      final opsPerSec = ((iterations / (elapsedMs > 0 ? elapsedMs : 1)) * 1000).toInt();

      debugPrint('🚀 [BENCHMARK] Passport MRZ Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op, ~$opsPerSec ops/sec)');
      expect(elapsedMs, lessThan(1000));
    });

    test('Indian Aadhaar Card Parser Performance Benchmark (1,000 runs)', () {
      const xmlQr =
          '<?xml version="1.0" encoding="UTF-8"?><PrintLetterBarcodeData uid="234567890124" name="Rajesh Kumar" gender="M" yob="1992"/>';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = AadhaarParser.parse(xmlQr);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      debugPrint('🚀 [BENCHMARK] Aadhaar Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op)');
      expect(elapsedMs, lessThan(1000));
    });

    test('PAN Card Fuzzy OCR Parser Performance Benchmark (1,000 runs)', () {
      const noisyPanText =
          'INCOME TAX DEPARTMENT\nPERMANENT ACCOUNT NUMBER CARD\n0ZMPS661 3E\nNAME: FRANCIS XAVIER';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = PanCardParser.parse(noisyPanText);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      debugPrint('🚀 [BENCHMARK] PAN Card Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op)');
      expect(elapsedMs, lessThan(1000));
    });

    test('AAMVA Driving License PDF417 Parser Performance Benchmark (1,000 runs)', () {
      const aamvaPayload =
          '@\n\nANSI 636000080002DL00390207DL\nDAQD1234567\nDCSDOE\nDACJOHN\nDBB19880415\n';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = DrivingLicenseParser.parse(aamvaPayload);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      debugPrint('🚀 [BENCHMARK] AAMVA DL Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op)');
      expect(elapsedMs, lessThan(1000));
    });

    test('ISO 3779 VIN Check Digit Parser Performance Benchmark (1,000 runs)', () {
      const vinStr = '1HGCR2F85HA123456';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = VinParser.parse(vinStr);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      debugPrint('🚀 [BENCHMARK] VIN Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op)');
      expect(elapsedMs, lessThan(1000));
    });

    test('GS1 Application Identifier Barcode Parser Performance Benchmark (1,000 runs)', () {
      const gs1Payload = '(01)00012345678905(17)20281231(10)LOT4587(30)24';

      final stopwatch = Stopwatch()..start();
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        final res = Gs1BarcodeParser.parse(gs1Payload);
        expect(res.isValid, isTrue);
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / iterations).toStringAsFixed(1);
      debugPrint('🚀 [BENCHMARK] GS1 Parser: $iterations runs in ${elapsedMs}ms ($avgMicroseconds µs/op)');
      expect(elapsedMs, lessThan(1000));
    });
  });
}
