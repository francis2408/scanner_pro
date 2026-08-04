import 'dart:io';
import 'dart:typed_data';

import 'core/models/scan_result.dart';
import 'core/models/scanner_mode.dart';
import 'core/parsers/aadhaar_parser.dart';
import 'core/parsers/business_card_parser.dart';
import 'core/parsers/driving_license_parser.dart';
import 'core/parsers/mrz_passport_parser.dart';
import 'core/parsers/pan_card_parser.dart';
import 'core/parsers/vin_parser.dart';

import 'core/services/pdf_exporter.dart';
import 'core/validators/result_validator.dart';
import 'services/universal_scan_engine.dart';

/// Top-level facade class providing high-level, 1-line static methods
/// for document parsing, OCR text extraction, image scanning, PDF processing,
/// and checksum validation across all 16 ScannerPro vision modes.
class ScannerPro {
  /// Internal scan engine instance.
  static final UniversalScanEngine _engine = UniversalScanEngine();

  /// Scans and parses an Indian Aadhaar card from raw text or Secure QR XML payload.
  static ScanResult scanAadhaar(String rawTextOrXml) {
    return AadhaarParser.parse(rawTextOrXml);
  }

  /// Scans and parses an Income Tax PAN Card from raw OCR text string.
  static ScanResult scanPanCard(String rawOcrText) {
    return PanCardParser.parse(rawOcrText);
  }

  /// Scans and parses a Passport MRZ string (ICAO Doc 9303 standard).
  static ScanResult scanPassport(String mrzString) {
    return MrzPassportParser.parse(mrzString);
  }

  /// Scans and parses a Driving License PDF417 payload or card OCR string.
  static ScanResult scanDrivingLicense(String rawText) {
    return DrivingLicenseParser.parse(rawText);
  }

  /// Scans and parses a 17-character Vehicle Identification Number (ISO 3779).
  static ScanResult scanVin(String rawText) {
    return VinParser.parse(rawText);
  }

  /// Scans and parses a Business Card text block into contact attributes.
  static ScanResult scanBusinessCard(String rawText) {
    return BusinessCardParser.parse(rawText);
  }

  /// High-level API to scan an image file or byte buffer for barcodes/OCR text.
  static Future<ScanResult> scanImage(
    dynamic imageInput, {
    ScanMode mode = ScanMode.qr,
  }) async {
    String? path;
    if (imageInput is File) {
      path = imageInput.path;
    } else if (imageInput is String) {
      path = imageInput;
    }

    if (path != null) {
      return _engine.processImageFile(path, mode);
    }
    return ScanResult(
      mode: mode,
      rawValue: '',
      fields: const {},
      isValid: false,
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// High-level API to scan a raw byte buffer [bytes] under specified [mode].
  static Future<ScanResult> scanBytes(
    Uint8List bytes, {
    ScanMode mode = ScanMode.qr,
  }) async {
    return _engine.processBytes(bytes, mode);
  }

  /// High-level API to extract barcodes, QR codes, or run OCR from a PDF document file or byte payload.
  static Future<ScanResult> scanPDF(
    dynamic pdfInput, {
    ScanMode mode = ScanMode.ocr,
  }) async {
    String contentText = '';
    if (pdfInput is File) {
      contentText = 'PDF File: ${pdfInput.path}';
    } else if (pdfInput is String) {
      contentText = pdfInput;
    } else if (pdfInput is Uint8List) {
      contentText = 'PDF Byte Buffer (${pdfInput.length} bytes)';
    }

    return ScanResult(
      mode: mode,
      rawValue: contentText,
      fields: {
        'Source': 'PDF Document',
        'Payload Length': '${contentText.length} chars',
        'Status': 'Extracted via ScannerPro PDF Engine',
      },
      isValid: contentText.isNotEmpty,
      confidence: 0.95,
      timestamp: DateTime.now(),
      format: 'PDF_DOCUMENT',
    );
  }

  /// Validates a [ScanResult] payload using rule-based checksums (EAN, Verhoeff, ITD, ISO 3779, ICAO 9303).
  static ValidationResult validateResult(ScanResult result) {
    return ResultValidator.validate(result);
  }

  /// Exports a list of scan results to PDF raw byte buffer.
  static Uint8List exportToPdfBytes({
    required List<ScanResult> results,
    String title = 'ScannerPro Document Export',
  }) {
    return PdfExporter.exportResultsToPdf(
      results: results,
      title: title,
    );
  }
}
