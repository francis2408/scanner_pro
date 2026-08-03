import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/core/models/scanner_mode.dart';
import 'package:scannerpro/core/parsers/aadhaar_parser.dart';
import 'package:scannerpro/core/parsers/driving_license_parser.dart';
import 'package:scannerpro/core/parsers/face_scanner_parser.dart';
import 'package:scannerpro/core/parsers/gs1_barcode_parser.dart';
import 'package:scannerpro/core/parsers/invoice_parser.dart';
import 'package:scannerpro/core/parsers/mrz_passport_parser.dart';
import 'package:scannerpro/core/parsers/pan_card_parser.dart';
import 'package:scannerpro/core/parsers/vin_parser.dart';
import 'package:scannerpro/core/services/document_scanner_service.dart';
import 'package:scannerpro/services/sample_card_presets.dart';

void main() {
  group('Universal Scanner Parsers Unit Tests', () {
    test('Passport MRZ 7-3-1 Checksum & Field Extractor Test', () {
      const sampleMrz =
          'P<USADICKSON<<BENJAMIN<FRANKLIN<<<<<<<<<<<<<\n1234567897USA8501019M3001019<<<<<<<<<<<<<<04';
      final result = MrzPassportParser.parse(sampleMrz);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.passport);
      expect(result.fields['Surname'], equals('DICKSON'));
      expect(result.fields['Given Names'], equals('BENJAMIN FRANKLIN'));
      expect(result.fields['Passport Number'], equals('123456789'));
      expect(result.fields['Passport Num Check'], equals('Valid ✓'));
      expect(result.fields['Issuing State'], equals('USA'));
      expect(result.fields['Sex'], equals('Male'));
    });

    test('Indian Aadhaar Card Verhoeff & Secure QR XML Test', () {
      expect(AadhaarParser.validateAadhaarVerhoeff('234567890124'), isTrue);

      const xmlQr =
          '<?xml version="1.0" encoding="UTF-8"?><PrintLetterBarcodeData uid="234567890124" name="Rajesh Kumar" gender="M" yob="1992"/>';
      final result = AadhaarParser.parse(xmlQr);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.aadhaar);
      expect(result.fields['Aadhaar Number'], equals('234567890124'));
      expect(result.fields['Full Name'], equals('Rajesh Kumar'));
      expect(result.fields['Gender'], equals('Male'));
    });

    test('PAN Card Category & Regex Extractor Test', () {
      const panCardText =
          'INCOME TAX DEPARTMENT\nGOVT OF INDIA\nABCPE1234F\nNAME: RAJESH KUMAR';
      final result = PanCardParser.parse(panCardText);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.pan);
      expect(result.fields['PAN Number'], equals('ABCPE1234F'));
      expect(result.fields['Holder Category'], equals('Individual / Person'));
    });

    test('PAN Card Fuzzy OCR & Space Removal Test', () {
      const noisyPanText =
          'INCOME TAX DEPARTMENT\nPERMANENT ACCOUNT NUMBER CARD\n0ZMPS661 3E\nNAME: FRANCIS XAVIER';
      final result = PanCardParser.parse(noisyPanText);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.pan);
      expect(result.fields['PAN Number'], equals('OZMPS6613E'));
      expect(result.fields['Holder Category'], equals('Individual / Person'));
    });

    test('Invoice & Bill AI OCR Parser Test', () {
      const sampleInvoice = '''GLOBAL SUPPLIERS CORP
INVOICE NO: INV-2026-8841
DATE: 2026-08-01  DUE: 2026-08-30
GSTIN: 27AAAAA0000A1Z5
--------------------------------
Item 1: Server Hardware Rack   \$1,250.00
Item 2: Fiber Optics Adapter     \$450.00
--------------------------------
SUBTOTAL:                      \$1,700.00
TAX (18%):                       \$306.00
TOTAL AMOUNT:                  \$2,006.00''';
      final result = InvoiceParser.parse(sampleInvoice);

      expect(result.isValid, isTrue);
      expect(result.fields['Vendor / Biller'], equals('GLOBAL SUPPLIERS CORP'));
      expect(result.fields['Invoice Number'], equals('INV-2026-8841'));
      expect(result.fields['Total Amount'], equals('\$2,006.00'));
      expect(result.fields['Tax / VAT / GST'], equals('\$306.00'));
    });

    test('DocumentScannerService Advanced Image Filters Test', () {
      final sampleBytes = Uint8List.fromList([50, 100, 150, 200, 250]);
      final shadowResult = DocumentScannerService.applyShadowRemovalFilter(sampleBytes);
      expect(shadowResult.length, equals(5));

      final binarized = DocumentScannerService.applyBinarizationFilter(sampleBytes, threshold: 128);
      expect(binarized[0], equals(0));
      expect(binarized[4], equals(255));

      final magicColor = DocumentScannerService.applyMagicColorFilter(sampleBytes);
      expect(magicColor.length, equals(5));
    });

    test('AAMVA Driving License PDF417 Parser Test', () {
      const aamvaPayload =
          '@\n\nANSI 636000080002DL00390207DL\nDAQD1234567\nDCSDOE\nDACJOHN\nDBB19880415\n';
      final result = DrivingLicenseParser.parse(aamvaPayload);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.drivingLicense);
      expect(result.fields['License Number'], equals('D1234567'));
      expect(result.fields['Last Name'], equals('DOE'));
      expect(result.fields['First Name'], equals('JOHN'));
    });

    test('ISO 3779 VIN Check Digit & WMI Manufacturer Lookup Test', () {
      const vinStr = '1HGCR2F85HA123456';
      final result = VinParser.parse(vinStr);

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.vin);
      expect(result.fields['VIN Number'], equals('1HGCR2F85HA123456'));
      expect(result.fields['Manufacturer / WMI'], equals('Honda (USA)'));
    });

    test('GS1 Application Identifier Barcode Parser Test', () {
      const gs1ParenPayload = '(01)00012345678905(17)20281231(10)LOT4587(30)24';
      final result1 = Gs1BarcodeParser.parse(gs1ParenPayload);

      expect(result1.isValid, isTrue);
      expect(result1.fields['GTIN (Product Code)'], equals('00012345678905'));
      expect(result1.fields['Expiry Date'], equals('2028-12-31'));
      expect(result1.fields['Batch/Lot Number'], equals('LOT4587'));
      expect(result1.fields['Quantity'], equals('24'));

      const gs1UnparenPayload = '01000123456789051728123110LOT4587|3024';
      final result2 = Gs1BarcodeParser.parse(gs1UnparenPayload);

      expect(result2.isValid, isTrue);
      expect(result2.fields['GTIN (Product Code)'], equals('00012345678905'));
      expect(result2.fields['Expiry Date'], equals('2028-12-31'));
      expect(result2.fields['Batch/Lot Number'], equals('LOT4587'));
      expect(result2.fields['Quantity'], equals('24'));

      // Dynamic Unstructured / Key-Value Text Barcode Payload Test
      const dynamicKvPayload =
          'GTIN: 98765432109876\nEXP: 2029-11-20\nBATCH: B99001\nQTY: 150';
      final result3 = Gs1BarcodeParser.parse(dynamicKvPayload);

      expect(result3.isValid, isTrue);
      expect(result3.fields['GTIN (Product Code)'], equals('98765432109876'));
      expect(result3.fields['Expiry Date'], equals('2029-11-20'));
      expect(result3.fields['Batch/Lot Number'], equals('B99001'));
      expect(result3.fields['Quantity'], equals('150'));
    });

    test('SampleCardPresets cover all 15 scan modes', () {
      for (final mode in ScanMode.values) {
        final samples = SampleCardPresets.getSamplesForMode(mode);
        expect(samples, isNotEmpty);

        final result = SampleCardPresets.processSample(samples.first);
        expect(result.mode, equals(mode));
        expect(result.fields, isNotEmpty);
      }
    });

    test('FaceScannerParser Vision AI Face Metrics & Landmark Verification Test', () {
      final result = FaceScannerParser.parse(
        'Face Detected Payload',
        extraMetadata: {
          'headEulerAngleY': 1.2,
          'headEulerAngleZ': 0.5,
          'headEulerAngleX': -0.8,
          'smilingProbability': 0.90,
          'leftEyeOpenProbability': 0.98,
          'rightEyeOpenProbability': 0.97,
        },
      );

      expect(result.isValid, isTrue);
      expect(result.mode, ScanMode.face);
      expect(result.confidence, greaterThanOrEqualTo(0.95));
      expect(result.verifications['faceDetected'], isTrue);
      expect(result.verifications['isFrontalPose'], isTrue);
      expect(result.verifications['areEyesOpen'], isTrue);
      expect(result.fields['Frontal Pose'], contains('Centered'));
    });
  });
}
