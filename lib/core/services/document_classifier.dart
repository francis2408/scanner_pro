import '../models/scanner_mode.dart';

/// Standard document categories supported by AI document classification.
enum DocumentCategory {
  invoice,
  receipt,
  passport,
  aadhaar,
  pan,
  drivingLicense,
  businessCard,
  vin,
  cheque,
  barcode,
  generalDocument,
}

/// Represents the classification output for a scanned document.
class DocumentClassificationResult {
  final DocumentCategory category;
  final double confidence;
  final List<String> detectedKeywords;
  final String description;

  const DocumentClassificationResult({
    required this.category,
    required this.confidence,
    required this.detectedKeywords,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'confidence': double.parse(confidence.toStringAsFixed(2)),
        'detectedKeywords': detectedKeywords,
        'description': description,
      };
}

/// AI-powered & heuristic document classifier analyzing OCR text patterns,
/// structural keyphrases, and payload signatures.
class DocumentClassifier {
  /// Classifies OCR raw text or scan result into a [DocumentCategory].
  static DocumentClassificationResult classify(
    String rawText, {
    Map<String, String>? fields,
    ScanMode? mode,
  }) {
    if (rawText.isEmpty) {
      return const DocumentClassificationResult(
        category: DocumentCategory.generalDocument,
        confidence: 0.50,
        detectedKeywords: [],
        description: 'Unclassified Empty Document',
      );
    }

    final upper = rawText.toUpperCase();
    final keywords = <String>[];

    // Bank Cheque check
    if (upper.contains('PAY TO THE ORDER OF') || upper.contains('CHEQUE') || upper.contains('MICR') || upper.contains('⑈') || upper.contains('⑆') || (mode == ScanMode.cheque) || RegExp(r'c[0-9]{6}c\s*[0-9]{9}a').hasMatch(rawText)) {
      keywords.addAll(['CHEQUE', 'MICR', 'BANK']);
      return DocumentClassificationResult(
        category: DocumentCategory.cheque,
        confidence: 0.98,
        detectedKeywords: keywords,
        description: 'Bank Cheque Financial Document',
      );
    }

    // Passport MRZ check
    if (upper.contains('P<') || upper.contains('PASSPORT') || upper.contains('ICAO') || (mode == ScanMode.passport)) {
      keywords.addAll(['PASSPORT', 'MRZ', 'P<']);
      return DocumentClassificationResult(
        category: DocumentCategory.passport,
        confidence: upper.contains('P<') ? 0.99 : 0.90,
        detectedKeywords: keywords,
        description: 'International Passport Document',
      );
    }

    // Aadhaar Card check
    if (upper.contains('AADHAAR') || upper.contains('GOVERNMENT OF INDIA') || RegExp(r'\b\d{4}\s\d{4}\s\d{4}\b').hasMatch(rawText) || (mode == ScanMode.aadhaar)) {
      keywords.addAll(['AADHAAR', 'UID', 'GOVT OF INDIA']);
      return DocumentClassificationResult(
        category: DocumentCategory.aadhaar,
        confidence: 0.98,
        detectedKeywords: keywords,
        description: 'Indian Aadhaar Identity Card',
      );
    }

    // PAN Card check
    if (upper.contains('INCOME TAX') || upper.contains('PERMANENT ACCOUNT') || RegExp(r'[A-Z]{5}[0-9]{4}[A-Z]').hasMatch(upper) || (mode == ScanMode.pan)) {
      keywords.addAll(['PAN', 'INCOME TAX', 'GOVT OF INDIA']);
      return DocumentClassificationResult(
        category: DocumentCategory.pan,
        confidence: 0.98,
        detectedKeywords: keywords,
        description: 'Indian Income Tax PAN Card',
      );
    }

    // Driving License check
    if (upper.contains('DRIVING LICENSE') || upper.contains('LICENCE') || upper.contains('DL NO') || upper.contains('ANSI ') || (mode == ScanMode.drivingLicense)) {
      keywords.addAll(['DRIVING LICENSE', 'DL']);
      return DocumentClassificationResult(
        category: DocumentCategory.drivingLicense,
        confidence: 0.95,
        detectedKeywords: keywords,
        description: 'Driving License Identity Document',
      );
    }

    // Invoice check
    if (upper.contains('INVOICE') || upper.contains('BILL TO') || upper.contains('TAX INVOICE') || upper.contains('DUE DATE') || (mode == ScanMode.invoice)) {
      keywords.addAll(['INVOICE', 'BILL TO', 'TAX INVOICE']);
      return DocumentClassificationResult(
        category: DocumentCategory.invoice,
        confidence: 0.95,
        detectedKeywords: keywords,
        description: 'Commercial Invoice & Billing Document',
      );
    }

    // Receipt check
    if (upper.contains('TOTAL') && (upper.contains('CHANGE') || upper.contains('SUBTOTAL') || upper.contains('CASH') || upper.contains('THANK YOU')) || (mode == ScanMode.receipt)) {
      keywords.addAll(['RECEIPT', 'TOTAL', 'SUBTOTAL']);
      return DocumentClassificationResult(
        category: DocumentCategory.receipt,
        confidence: 0.93,
        detectedKeywords: keywords,
        description: 'Retail Store Sales Receipt',
      );
    }

    // Business Card check
    if (upper.contains('ENGINEER') || upper.contains('MANAGER') || upper.contains('DIRECTOR') || upper.contains('SOFTWARE') || (upper.contains('@') && upper.contains('WWW.')) || (mode == ScanMode.businessCard)) {
      keywords.addAll(['BUSINESS CARD', 'EMAIL', 'TITLE']);
      return DocumentClassificationResult(
        category: DocumentCategory.businessCard,
        confidence: 0.90,
        detectedKeywords: keywords,
        description: 'Professional Business Contact Card',
      );
    }

    // VIN Number check
    if (upper.contains('VIN') || (upper.length == 17 && RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(upper)) || (mode == ScanMode.vin)) {
      keywords.addAll(['VIN', 'VEHICLE ID']);
      return DocumentClassificationResult(
        category: DocumentCategory.vin,
        confidence: 0.96,
        detectedKeywords: keywords,
        description: 'Vehicle Identification Number (VIN)',
      );
    }

    // Barcode check
    if (mode == ScanMode.qr || mode == ScanMode.barcode || mode == ScanMode.pdf417 || mode == ScanMode.multiCode) {
      return DocumentClassificationResult(
        category: DocumentCategory.barcode,
        confidence: 0.99,
        detectedKeywords: [mode?.name.toUpperCase() ?? 'BARCODE'],
        description: '1D/2D Barcode Data Payload',
      );
    }

    // Fallback general document
    return DocumentClassificationResult(
      category: DocumentCategory.generalDocument,
      confidence: 0.75,
      detectedKeywords: ['TEXT', 'DOCUMENT'],
      description: 'Standard Text Document',
    );
  }
}
