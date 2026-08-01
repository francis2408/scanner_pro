import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/core/models/scan_result.dart';
import 'package:scannerpro/core/models/scanner_mode.dart';
import 'package:scannerpro/services/external_lookup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Real-Time API Pipeline Verification', () {
    test('1. Product Barcode Open Food Facts API Lookup Test', () async {
      final sampleBarcodeResult = ScanResult(
        mode: ScanMode.barcode,
        rawValue: '5449000000996',
        isValid: true,
        confidence: 0.99,
        fields: {'Symbology Format': 'EAN-13', 'Value Type': 'PRODUCT BARCODE'},
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleBarcodeResult,
      );

      debugPrint('\n📦 [API RESULT] Product Barcode Lookup (5449000000996):');
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails.isNotEmpty, isTrue);
    });

    test('2. Book ISBN Open Library API Lookup Test', () async {
      final sampleIsbnResult = ScanResult(
        mode: ScanMode.barcode,
        rawValue: '9780131103627',
        isValid: true,
        confidence: 0.99,
        fields: {
          'Symbology Format': 'EAN-13 / ISBN',
          'Value Type': 'BOOK ISBN',
        },
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleIsbnResult,
      );

      debugPrint('\n📚 [API RESULT] Book ISBN Lookup (9780131103627):');
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails.isNotEmpty, isTrue);
    });

    test('3. Web URL QR Code Gateway Metadata Test', () async {
      final sampleUrlResult = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'https://flutter.dev',
        isValid: true,
        confidence: 0.99,
        fields: {'Symbology Format': 'QR Code', 'Value Type': 'WEB URL'},
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleUrlResult,
      );

      debugPrint('\n🔗 [API RESULT] Web URL QR Lookup (https://flutter.dev):');
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails.isNotEmpty, isTrue);
    });

    test('4. Geo Location Reverse Geocoding API Test', () async {
      final sampleGeoResult = ScanResult(
        mode: ScanMode.qr,
        rawValue: 'geo:37.7749,-122.4194',
        isValid: true,
        confidence: 0.99,
        fields: {'Symbology Format': 'QR Code', 'Value Type': 'GEO LOCATION'},
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleGeoResult,
      );

      debugPrint(
        '\n🗺️ [API RESULT] Geo QR Reverse Geocode Lookup (37.7749,-122.4194):',
      );
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails.isNotEmpty, isTrue);
    });

    test('5. Vehicle VIN NHTSA API Lookup Test', () async {
      final sampleVinResult = ScanResult(
        mode: ScanMode.vin,
        rawValue: '1HGCR2F83HA000000',
        isValid: true,
        confidence: 0.99,
        fields: {'17-Char VIN Code': '1HGCR2F83HA000000'},
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleVinResult,
      );

      debugPrint('\n🚗 [API RESULT] Vehicle VIN Lookup (1HGCR2F83HA000000):');
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails.isNotEmpty, isTrue);
    });

    test('6. UPI Payment QR Code Account Details Extractor Test', () async {
      final sampleUpiResult = ScanResult(
        mode: ScanMode.qr,
        rawValue:
            'upi://pay?pa=xavierfrancis263@oksbi&pn=Francis%20Xavier&aid=uGICAgICt--_UfA&am=500&mc=5411',
        isValid: true,
        confidence: 0.99,
        fields: {'Symbology Format': 'QR Code', 'Value Type': 'UPI PAYMENT'},
      );

      final apiDetails = await ExternalLookupService.fetchExternalDetails(
        sampleUpiResult,
      );

      debugPrint('\n💳 [API RESULT] UPI Payment QR Account Details:');
      apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

      expect(apiDetails['Account Holder Name'], equals('Francis Xavier'));
      expect(
        apiDetails['UPI Virtual Address (VPA)'],
        equals('xavierfrancis263@oksbi'),
      );
      expect(apiDetails['Payment App Provider'], equals('Google Pay (GPay)'));
      expect(
        apiDetails['Associated Bank'],
        equals('State Bank of India (SBI)'),
      );
      expect(apiDetails['Requested Amount'], equals('₹500 INR'));
    });

    test(
      '7. Indian Aadhaar Card UID & Postal Region API Lookup Test',
      () async {
        final sampleAadhaarResult = ScanResult(
          mode: ScanMode.aadhaar,
          rawValue: '2345 6789 0124 Pincode: 560001',
          isValid: true,
          confidence: 0.96,
          fields: {
            'Card Type': 'Aadhaar Card (India)',
            'Aadhaar Number': '2345 6789 0124',
            'Pincode': '560001',
          },
        );

        final apiDetails = await ExternalLookupService.fetchExternalDetails(
          sampleAadhaarResult,
        );

        debugPrint('\n🆔 [API RESULT] Indian Aadhaar Card Details:');
        apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

        expect(apiDetails['UID Verhoeff Checksum'], equals('Valid Checksum ✓'));
        expect(apiDetails.isNotEmpty, isTrue);
      },
    );

    test(
      '8. Income Tax PAN Card ITD Taxpayer Directory API Lookup Test',
      () async {
        final samplePanResult = ScanResult(
          mode: ScanMode.pan,
          rawValue: 'ABCPE1234F',
          isValid: true,
          confidence: 0.96,
          fields: {
            'Document Type': 'Income Tax PAN Card (India)',
            'PAN Number': 'ABCPE1234F',
          },
        );

        final apiDetails = await ExternalLookupService.fetchExternalDetails(
          samplePanResult,
        );

        debugPrint('\n💳 [API RESULT] Income Tax PAN Card Details:');
        apiDetails.forEach((key, val) => debugPrint('   • $key: $val'));

        expect(apiDetails['Taxpayer Category'], equals('Individual / Person'));
        expect(apiDetails['Surname Initial'], equals('E'));
      },
    );
  });
}
