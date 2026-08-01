import 'package:flutter/material.dart';

/// Supported scanning modes in Universal Scanner Pro.
enum ScanMode {
  /// QR Code scanning mode (URLs, vCard, WiFi, UPI, Geo).
  qr,

  /// 1D Retail and logistics barcode scanning mode (EAN, UPC, Code128).
  barcode,

  /// PDF417 stacked 2D barcode scanning mode.
  pdf417,

  /// Passport MRZ (Machine Readable Zone) scanning mode.
  passport,

  /// Indian Aadhaar Card Secure QR & OCR mode.
  aadhaar,

  /// Income Tax PAN Card OCR mode.
  pan,

  /// Driving License PDF417 & OCR mode.
  drivingLicense,

  /// ISO 3779 17-character VIN number mode.
  vin,

  /// General OCR text recognition mode.
  ocr,

  /// Face detection & landmark analysis mode.
  face,
}

/// Extension methods for [ScanMode] providing UI metadata.
extension ScanModeExtension on ScanMode {
  /// The user-facing display title for this mode.
  String get title {
    switch (this) {
      case ScanMode.qr:
        return 'QR Code';
      case ScanMode.barcode:
        return '1D Barcode';
      case ScanMode.pdf417:
        return 'PDF417 Barcode';
      case ScanMode.passport:
        return 'Passport (MRZ)';
      case ScanMode.aadhaar:
        return 'Aadhaar Card';
      case ScanMode.pan:
        return 'PAN Card';
      case ScanMode.drivingLicense:
        return 'Driving License';
      case ScanMode.vin:
        return 'VIN Number';
      case ScanMode.ocr:
        return 'Text OCR';
      case ScanMode.face:
        return 'Face Detection';
    }
  }

  /// The user-facing subtitle description for this mode.
  String get subtitle {
    switch (this) {
      case ScanMode.qr:
        return 'URLs, WiFi, Contact, VCard, Raw Text';
      case ScanMode.barcode:
        return 'EAN-13, EAN-8, UPC-A, Code39, Code128';
      case ScanMode.pdf417:
        return 'Stacked 2D barcode for IDs & Boarding Passes';
      case ScanMode.passport:
        return 'ICAO Doc 9303 2-line & 3-line MRZ zone';
      case ScanMode.aadhaar:
        return 'Aadhaar Secure QR & Card OCR text';
      case ScanMode.pan:
        return 'Indian Income Tax Permanent Account Number';
      case ScanMode.drivingLicense:
        return 'AAMVA PDF417 format & Regional DL OCR';
      case ScanMode.vin:
        return '17-character ISO 3779 vehicle number';
      case ScanMode.ocr:
        return 'On-device text block & line recognition';
      case ScanMode.face:
        return 'Face mesh landmarks, head pose & liveness';
    }
  }

  /// The icon representing this mode.
  IconData get icon {
    switch (this) {
      case ScanMode.qr:
        return Icons.qr_code_scanner_rounded;
      case ScanMode.barcode:
        return Icons.document_scanner_rounded;
      case ScanMode.pdf417:
        return Icons.qr_code_2_rounded;
      case ScanMode.passport:
        return Icons.badge_rounded;
      case ScanMode.aadhaar:
        return Icons.credit_card_rounded;
      case ScanMode.pan:
        return Icons.subtitles_rounded;
      case ScanMode.drivingLicense:
        return Icons.directions_car_rounded;
      case ScanMode.vin:
        return Icons.minor_crash_rounded;
      case ScanMode.ocr:
        return Icons.text_snippet_rounded;
      case ScanMode.face:
        return Icons.face_retouching_natural_rounded;
    }
  }

  /// Guidance text displayed over camera viewfinder for this mode.
  String get guideText {
    switch (this) {
      case ScanMode.qr:
        return 'Align QR Code within the square frame';
      case ScanMode.barcode:
        return 'Center barcode inside horizontal guide';
      case ScanMode.pdf417:
        return 'Align PDF417 code inside rectangle';
      case ScanMode.passport:
        return 'Position MRZ 2-line string at bottom of camera';
      case ScanMode.aadhaar:
        return 'Align Aadhaar QR or front side within frame';
      case ScanMode.pan:
        return 'Position PAN card front side inside guide';
      case ScanMode.drivingLicense:
        return 'Scan DL barcode on back or front text side';
      case ScanMode.vin:
        return 'Position 17-digit VIN code inside guide line';
      case ScanMode.ocr:
        return 'Point camera at any printed or clear text';
      case ScanMode.face:
        return 'Position face clearly inside oval outline';
    }
  }

  /// Target aspect ratio (width / height) for camera reticle cutout.
  double get targetAspectRatio {
    switch (this) {
      case ScanMode.qr:
        return 1.0;
      case ScanMode.barcode:
        return 2.5;
      case ScanMode.pdf417:
        return 2.0;
      case ScanMode.passport:
        return 1.42;
      case ScanMode.aadhaar:
      case ScanMode.pan:
      case ScanMode.drivingLicense:
        return 1.58;
      case ScanMode.vin:
        return 3.2;
      case ScanMode.ocr:
        return 1.5;
      case ScanMode.face:
        return 0.85;
    }
  }

  /// High-level category grouping for this scan mode.
  String get category {
    switch (this) {
      case ScanMode.qr:
      case ScanMode.barcode:
      case ScanMode.pdf417:
        return 'Barcodes';
      case ScanMode.passport:
      case ScanMode.aadhaar:
      case ScanMode.pan:
      case ScanMode.drivingLicense:
        return 'ID Documents';
      case ScanMode.vin:
        return 'Automotive';
      case ScanMode.ocr:
      case ScanMode.face:
        return 'Vision AI';
    }
  }
}
