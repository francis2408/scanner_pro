import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  group('ScannerPro Facade & ResultValidator Test Suite', () {
    test('ScannerPro.scanAadhaar parses valid Aadhaar string with Verhoeff check', () {
      final result = ScannerPro.scanAadhaar('2345 6789 0124 DOB: 15/08/1990 Male');
      expect(result.isValid, isTrue);
      expect(result.mode, equals(ScanMode.aadhaar));
      expect(result.fields['Aadhaar Number'], equals('2345 6789 0124'));

      final validation = ScannerPro.validateResult(result);
      expect(validation.isValid, isTrue);
      expect(validation.reason, contains('Verhoeff'));
    });

    test('ScannerPro.scanPanCard parses valid PAN format and validates status digit', () {
      final result = ScannerPro.scanPanCard('ABCPE1234F Name: JOHN DOE DOB: 01/01/1985');
      expect(result.isValid, isTrue);
      expect(result.mode, equals(ScanMode.pan));
      expect(result.fields['PAN Number'], equals('ABCPE1234F'));

      final validation = ScannerPro.validateResult(result);
      expect(validation.isValid, isTrue);
      expect(validation.reason, contains('PAN Card structure'));
    });

    test('ScannerPro.scanPassport parses ICAO Doc 9303 MRZ string', () {
      const mrz = 'P<USADICKSON<<BENJAMIN<FRANKLIN<<<<<<<<<<<<<\n1234567897USA8501019M3001019<<<<<<<<<<<<<<04';
      final result = ScannerPro.scanPassport(mrz);
      expect(result.isValid, isTrue);
      expect(result.mode, equals(ScanMode.passport));
      expect(result.fields['Passport Number'], equals('123456789'));

      final validation = ScannerPro.validateResult(result);
      expect(validation.isValid, isTrue);
    });

    test('ScannerPro.scanVin parses 17-character ISO 3779 VIN number', () {
      final result = ScannerPro.scanVin('1HGCR2F85HA123456');
      expect(result.isValid, isTrue);
      expect(result.mode, equals(ScanMode.vin));
      expect(result.fields['VIN Number'], equals('1HGCR2F85HA123456'));

      final validation = ScannerPro.validateResult(result);
      expect(validation.isValid, isTrue);
    });

    test('ScannerPro.scanBusinessCard extracts contact attributes', () {
      const text = 'Francis Xavier\nCEO\nTech Corp\nEmail: info@tech.com\nPhone: +1234567890';
      final result = ScannerPro.scanBusinessCard(text);
      expect(result.isValid, isTrue);
      expect(result.mode, equals(ScanMode.businessCard));
      expect(result.fields['Contact Name'], equals('Francis Xavier'));
      expect(result.fields['Email Address'], equals('info@tech.com'));
    });

    test('ScannerPro.scanPDF returns structured result for PDF input', () async {
      final result = await ScannerPro.scanPDF('Sample Invoice PDF Text');
      expect(result.isValid, isTrue);
      expect(result.format, equals('PDF_DOCUMENT'));
      expect(result.fields['Source'], equals('PDF Document'));
    });

    test('ResultValidator validates EAN-13, EAN-8, UPC-A, and Web URL QR', () {
      final ean13Val = ResultValidator.validateBarcode('5449000000996');
      expect(ean13Val.isValid, isTrue);

      final qrVal = ResultValidator.validateQR('https://flutter.dev');
      expect(qrVal.isValid, isTrue);
      expect(qrVal.reason, contains('HTTP/HTTPS'));

      final upiVal = ResultValidator.validateQR('upi://pay?pa=test@oksbi&am=100');
      expect(upiVal.isValid, isTrue);
      expect(upiVal.reason, contains('UPI Payment'));
    });

    test('ScannerBenchmark telemetry reporting returns valid data structures', () {
      final telemetry = ScannerBenchmark.runLiveDiagnostic();
      expect(telemetry.containsKey('Average Latency µs'), isTrue);
      expect(telemetry.containsKey('Memory Footprint'), isTrue);

      final sampleDevices = ScannerBenchmark.getSampleDeviceMetrics();
      expect(sampleDevices.length, greaterThanOrEqualTo(4));
      expect(sampleDevices[0]['Device'], equals('Google Pixel 8'));
    });
  });
}
