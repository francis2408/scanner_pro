import 'package:flutter/foundation.dart' show immutable;
import '../models/scan_result.dart';
import '../parsers/aadhaar_parser.dart';
import '../parsers/driving_license_parser.dart';
import '../parsers/gs1_barcode_parser.dart';
import '../parsers/mrz_passport_parser.dart';
import '../parsers/pan_card_parser.dart';
import '../parsers/vin_parser.dart';

/// Result of a validation check on a scan payload or result object.
@immutable
class ValidationResult {
  /// Whether the scanned item passed validation checks.
  final bool isValid;

  /// Human-readable explanation of validation outcome or failure reason.
  final String reason;

  /// Clean, standardized, or formatted output string (if valid).
  final String? formattedValue;

  /// Confidence rating from 0.0 to 1.0.
  final double confidence;

  const ValidationResult({
    required this.isValid,
    required this.reason,
    this.formattedValue,
    this.confidence = 1.0,
  });

  /// Factory constructor for successful validation.
  factory ValidationResult.valid({
    required String formattedValue,
    String reason = 'Validation passed successfully',
    double confidence = 1.0,
  }) {
    return ValidationResult(
      isValid: true,
      reason: reason,
      formattedValue: formattedValue,
      confidence: confidence,
    );
  }

  /// Factory constructor for failed validation.
  factory ValidationResult.invalid({
    required String reason,
    double confidence = 0.0,
  }) {
    return ValidationResult(
      isValid: false,
      reason: reason,
      confidence: confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'isValid': isValid,
        'reason': reason,
        'formattedValue': formattedValue,
        'confidence': confidence,
      };

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, reason: "$reason", formatted: "$formattedValue")';
}

/// Unified Result Validator suite for ScannerPro.
class ResultValidator {
  /// Validates a general [ScanResult] based on its detection format/mode.
  static ValidationResult validate(ScanResult result) {
    if (!result.isValid) {
      return ValidationResult.invalid(
        reason: 'Scan result marked invalid by engine',
        confidence: result.confidence,
      );
    }

    final raw = result.rawValue.trim();

    // Route to specialized validator based on mode/fields
    if (result.fields.containsKey('Aadhaar Number')) {
      return validateAadhaar(raw);
    } else if (result.fields.containsKey('PAN Number')) {
      return validatePAN(raw);
    } else if (result.fields.containsKey('VIN')) {
      return validateVIN(raw);
    } else if (result.fields.containsKey('Passport Number')) {
      return validatePassport(raw);
    } else if (result.fields.containsKey('DL Number')) {
      return validateDrivingLicense(raw);
    } else if (result.format != null && result.format!.contains('QR')) {
      return validateQR(raw);
    } else {
      return validateBarcode(raw, format: result.format);
    }
  }

  /// Validates 1D/2D Retail and Logistics Barcodes (EAN-13, EAN-8, UPC-A, GS1).
  static ValidationResult validateBarcode(String barcode, {String? format}) {
    final clean = barcode.replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) {
      return ValidationResult.invalid(reason: 'Barcode content is empty');
    }

    // EAN-13 Checksum check
    if (clean.length == 13 && RegExp(r'^\d{13}$').hasMatch(clean)) {
      if (_validateEan13Checksum(clean)) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid EAN-13 barcode with correct Modulo-10 checksum',
        );
      } else {
        return ValidationResult.invalid(
          reason: 'Invalid EAN-13 Modulo-10 checksum digit',
        );
      }
    }

    // EAN-8 Checksum check
    if (clean.length == 8 && RegExp(r'^\d{8}$').hasMatch(clean)) {
      if (_validateEan8Checksum(clean)) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid EAN-8 barcode with correct Modulo-10 checksum',
        );
      } else {
        return ValidationResult.invalid(
          reason: 'Invalid EAN-8 Modulo-10 checksum digit',
        );
      }
    }

    // UPC-A Checksum check
    if (clean.length == 12 && RegExp(r'^\d{12}$').hasMatch(clean)) {
      if (_validateUpcAChecksum(clean)) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid UPC-A barcode with correct Modulo-10 checksum',
        );
      }
    }

    // GS1 Barcode parsing check
    if (clean.contains('(01)') || clean.contains('(10)')) {
      final parsedGs1 = Gs1BarcodeParser.parse(clean);
      if (parsedGs1.isValid) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid GS1 AI structured barcode',
        );
      }
    }

    return ValidationResult.valid(
      formattedValue: clean,
      reason: 'Standard raw barcode payload accepted',
    );
  }

  /// Validates QR Codes (URLs, UPI, vCard, WiFi).
  static ValidationResult validateQR(String qrPayload) {
    final clean = qrPayload.trim();
    if (clean.isEmpty) {
      return ValidationResult.invalid(reason: 'QR payload is empty');
    }

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.hasAuthority) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid HTTP/HTTPS Web URL',
        );
      }
    }

    if (clean.startsWith('upi://pay')) {
      final uri = Uri.tryParse(clean);
      if (uri != null && uri.queryParameters.containsKey('pa')) {
        return ValidationResult.valid(
          formattedValue: clean,
          reason: 'Valid Indian UPI Payment QR Code',
        );
      }
    }

    if (clean.startsWith('BEGIN:VCARD')) {
      return ValidationResult.valid(
        formattedValue: clean,
        reason: 'Valid vCard Contact QR Code',
      );
    }

    if (clean.startsWith('WIFI:')) {
      return ValidationResult.valid(
        formattedValue: clean,
        reason: 'Valid Wi-Fi Credentials QR Code',
      );
    }

    return ValidationResult.valid(
      formattedValue: clean,
      reason: 'Valid General Text QR Code',
    );
  }

  /// Validates 12-digit Indian Aadhaar number using the UIDAI Verhoeff D10 algorithm.
  static ValidationResult validateAadhaar(String rawInput) {
    final parsed = AadhaarParser.parse(rawInput);
    final uid = parsed.fields['Aadhaar Number'];
    if (uid != null) {
      final clean = uid.replaceAll(' ', '');
      if (AadhaarParser.validateAadhaarVerhoeff(clean)) {
        return ValidationResult.valid(
          formattedValue: uid,
          reason: 'UIDAI Verhoeff D10 Checksum Validated ✓',
        );
      }
    }
    return ValidationResult.invalid(
      reason: 'Invalid 12-digit Aadhaar UID or Verhoeff Checksum Failure',
    );
  }

  /// Validates Income Tax PAN Card (10-char alphanumeric sequence).
  static ValidationResult validatePAN(String rawInput) {
    final parsed = PanCardParser.parse(rawInput);
    final pan = parsed.fields['PAN Number'];
    if (pan != null && PanCardParser.validatePan(pan)) {
      return ValidationResult.valid(
        formattedValue: pan,
        reason: 'Valid Indian Income Tax PAN Card structure',
      );
    }
    return ValidationResult.invalid(
      reason: 'Invalid 10-character PAN format (Expected 5 letters, 4 digits, 1 letter)',
    );
  }

  /// Validates 17-character Vehicle Identification Number (ISO 3779 standard).
  static ValidationResult validateVIN(String rawInput) {
    final parsed = VinParser.parse(rawInput);
    final vin = parsed.fields['VIN'];
    if (vin != null && VinParser.validateVin(vin)) {
      return ValidationResult.valid(
        formattedValue: vin,
        reason: 'Valid 17-character ISO 3779 VIN with correct check digit',
      );
    }
    return ValidationResult.invalid(
      reason: 'Invalid 17-character VIN checksum or forbidden characters (I, O, Q)',
    );
  }

  /// Validates Passport MRZ 2-line or 3-line string (ICAO Doc 9303 standard).
  static ValidationResult validatePassport(String rawInput) {
    final parsed = MrzPassportParser.parse(rawInput);
    if (parsed.isValid && parsed.fields.containsKey('Passport Number')) {
      return ValidationResult.valid(
        formattedValue: parsed.fields['Passport Number']!,
        reason: 'Valid ICAO Doc 9303 Passport MRZ check digits',
      );
    }
    return ValidationResult.invalid(
      reason: 'Invalid Passport MRZ format or checksum mismatch',
    );
  }

  /// Validates Driving License (AAMVA or regional Indian DL).
  static ValidationResult validateDrivingLicense(String rawInput) {
    final parsed = DrivingLicenseParser.parse(rawInput);
    if (parsed.isValid && parsed.fields.containsKey('DL Number')) {
      return ValidationResult.valid(
        formattedValue: parsed.fields['DL Number']!,
        reason: 'Valid Driving License barcode or card layout',
      );
    }
    return ValidationResult.invalid(
      reason: 'Could not extract valid Driving License number',
    );
  }

  // --- Internal Checksum Helpers ---

  static bool _validateEan13Checksum(String ean) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      int digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit : digit * 3;
    }
    int check = (10 - (sum % 10)) % 10;
    return check == int.parse(ean[12]);
  }

  static bool _validateEan8Checksum(String ean) {
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      int digit = int.parse(ean[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    int check = (10 - (sum % 10)) % 10;
    return check == int.parse(ean[6]);
  }

  static bool _validateUpcAChecksum(String upc) {
    int sum = 0;
    for (int i = 0; i < 11; i++) {
      int digit = int.parse(upc[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit;
    }
    int check = (10 - (sum % 10)) % 10;
    return check == int.parse(upc[11]);
  }
}
