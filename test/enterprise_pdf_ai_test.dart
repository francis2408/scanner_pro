import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise Features & AI Verification Suite', () {
    test('1. AI Document Classification Engine Verification', () {
      // Passport MRZ classification
      final passportRes = DocumentClassifier.classify('P<INDXAVIER<<FRANCIS<<<<<<<<<<<<<<<<<<<<<<');
      expect(passportRes.category, equals(DocumentCategory.passport));
      expect(passportRes.confidence, greaterThanOrEqualTo(0.90));

      // Aadhaar Card classification
      final aadhaarRes = DocumentClassifier.classify('GOVERNMENT OF INDIA 2345 6789 0124 DOB: 15/08/1995');
      expect(aadhaarRes.category, equals(DocumentCategory.aadhaar));
      expect(aadhaarRes.confidence, greaterThanOrEqualTo(0.95));

      // Income Tax PAN Card classification
      final panRes = DocumentClassifier.classify('INCOME TAX DEPARTMENT ABCPE1234F FRANCIS XAVIER');
      expect(panRes.category, equals(DocumentCategory.pan));
      expect(panRes.confidence, greaterThanOrEqualTo(0.95));

      // Invoice classification
      final invoiceRes = DocumentClassifier.classify('INVOICE #INV-2026-001 BILL TO ACME CORP DUE DATE 30 DAYS');
      expect(invoiceRes.category, equals(DocumentCategory.invoice));
      expect(invoiceRes.confidence, greaterThanOrEqualTo(0.90));

      // Store Receipt classification
      final receiptRes = DocumentClassifier.classify(r'RETAIL STORE RECEIPT SUBTOTAL $50.00 TAX $4.00 TOTAL $54.00 THANK YOU');
      expect(receiptRes.category, equals(DocumentCategory.receipt));
      expect(receiptRes.confidence, greaterThanOrEqualTo(0.90));

      // Business Card classification
      final bcardRes = DocumentClassifier.classify('FRANCIS XAVIER SENIOR SOFTWARE ENGINEER EMAIL: TEST@DEV.COM WWW.DEV.COM');
      expect(bcardRes.category, equals(DocumentCategory.businessCard));
      expect(bcardRes.confidence, greaterThanOrEqualTo(0.90));

      // Vehicle VIN classification
      final vinRes = DocumentClassifier.classify('1HGCR2F83HA000000 VIN VEHICLE ID');
      expect(vinRes.category, equals(DocumentCategory.vin));
      expect(vinRes.confidence, greaterThanOrEqualTo(0.90));
    });

    test('2. PDF Export with Watermark, Encryption, Digital Signature & Searchable Layer', () {
      final res1 = ScanResult(
        mode: ScanMode.invoice,
        rawValue: 'INVOICE_1001',
        fields: {r'Vendor': r'ScannerPro Tech Inc', r'Total': r'$499.00'},
        format: 'DOCUMENT',
      );

      final pdfBytes = PdfExportUtil.exportResultsToPdf(
        results: [res1],
        title: 'Enterprise Scanned Invoice',
        watermarkText: 'CONFIDENTIAL',
        password: 'secure_password_123',
        isEncrypted: true,
        digitalSignature: true,
        isSearchablePdf: true,
        enableCompression: true,
      );

      final pdfStr = String.fromCharCodes(pdfBytes);

      expect(pdfBytes.length, greaterThan(150));
      expect(pdfStr, contains('%PDF-1.4'));
      expect(pdfStr, contains('CONFIDENTIAL'));
      expect(pdfStr, contains('/Encrypt'));
      expect(pdfStr, contains('/Sig'));
      expect(pdfStr, contains('/Adobe.PPKLite'));
    });

    test('3. Document Image Quality & Compression Utilities', () {
      final sampleBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final compressed = DocumentScannerService.compressImageBytes(sampleBytes, quality: 0.5);

      expect(compressed.length, lessThan(sampleBytes.length));
    });

    test('4. Full Engine Pipeline AI Classification Integration', () async {
      final engine = UniversalScanEngine();
      final sampleBytes = Uint8List.fromList(r'INVOICE #998822 BILL TO GOOGLE INC TOTAL $1500'.codeUnits);

      final result = await engine.processBytes(sampleBytes, ScanMode.ocr);

      expect(result.isValid, isTrue);
      expect(result.documentCategory, isNotNull);
      expect(result.metadata.containsKey('aiClassification'), isTrue);
    });
  });
}
