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

  /// Auto Document Edge Detection, Quad Cropping & Perspective Correction mode.
  document,

  /// Invoice and Bill OCR text recognition parser.
  invoice,

  /// Store Receipt OCR text recognition parser.
  receipt,

  /// Business Card Contact OCR parser.
  businessCard,

  /// Multi-Code simultaneous QR and 1D/2D Barcode scanner mode.
  multiCode,

  /// Bank Cheque MICR codeline and routing number parser mode.
  cheque,
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
      case ScanMode.document:
        return 'Document Scanner';
      case ScanMode.invoice:
        return 'Invoice OCR';
      case ScanMode.receipt:
        return 'Receipt OCR';
      case ScanMode.businessCard:
        return 'Business Card';
      case ScanMode.multiCode:
        return 'Multi-Code';
      case ScanMode.cheque:
        return 'Bank Cheque';
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
      case ScanMode.document:
        return 'Auto edge detection, perspective crop & PDF';
      case ScanMode.invoice:
        return 'Bills, tax invoices, totals, vendor & items';
      case ScanMode.receipt:
        return 'Store receipts, totals, tax & item lists';
      case ScanMode.businessCard:
        return 'Name, title, company, email, phone & web';
      case ScanMode.multiCode:
        return 'Simultaneous multi-QR and barcode pass';
      case ScanMode.cheque:
        return 'MICR codeline, cheque #, routing & account #';
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
      case ScanMode.document:
        return Icons.crop_free_rounded;
      case ScanMode.invoice:
        return Icons.receipt_long_rounded;
      case ScanMode.receipt:
        return Icons.receipt_rounded;
      case ScanMode.businessCard:
        return Icons.contact_page_rounded;
      case ScanMode.multiCode:
        return Icons.filter_center_focus_rounded;
      case ScanMode.cheque:
        return Icons.account_balance_rounded;
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
      case ScanMode.document:
        return 'Align document page boundaries within frame';
      case ScanMode.invoice:
        return 'Position bill or invoice inside guide';
      case ScanMode.receipt:
        return 'Center receipt text clearly within frame';
      case ScanMode.businessCard:
        return 'Center business card front inside guide';
      case ScanMode.multiCode:
        return 'Hold camera steady over multiple codes';
      case ScanMode.cheque:
        return 'Align bottom MICR codeline of cheque within reticle';
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
      case ScanMode.businessCard:
        return 1.58;
      case ScanMode.vin:
        return 3.2;
      case ScanMode.ocr:
      case ScanMode.invoice:
      case ScanMode.receipt:
        return 1.5;
      case ScanMode.document:
        return 1.33;
      case ScanMode.multiCode:
        return 1.2;
      case ScanMode.face:
        return 0.85;
      case ScanMode.cheque:
        return 2.6;
    }
  }

  /// High-level category grouping for this scan mode.
  String get category {
    switch (this) {
      case ScanMode.qr:
      case ScanMode.barcode:
      case ScanMode.pdf417:
      case ScanMode.multiCode:
        return 'Barcodes';
      case ScanMode.passport:
      case ScanMode.aadhaar:
      case ScanMode.pan:
      case ScanMode.drivingLicense:
      case ScanMode.businessCard:
        return 'ID & Cards';
      case ScanMode.vin:
        return 'Automotive';
      case ScanMode.cheque:
        return 'Financial';
      case ScanMode.ocr:
      case ScanMode.face:
      case ScanMode.document:
      case ScanMode.invoice:
      case ScanMode.receipt:
        return 'Vision AI';
    }
  }
}
