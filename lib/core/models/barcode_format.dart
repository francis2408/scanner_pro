/// Barcode symbology formats supported by ScannerPro.
enum BarcodeFormatFilter {
  /// All supported 1D and 2D barcode formats.
  all,

  /// QR Code 2D matrix symbology.
  qrCode,

  /// Code 128 1D linear symbology.
  code128,

  /// PDF417 2D stacked barcode symbology.
  pdf417,

  /// Data Matrix 2D symbology.
  dataMatrix,

  /// EAN-13 European Article Numbering barcode format.
  ean13,

  /// EAN-8 European Article Numbering barcode format.
  ean8,

  /// UPC-A Universal Product Code barcode format.
  upcA,

  /// UPC-E Universal Product Code barcode format.
  upcE,

  /// Code 39 1D linear barcode format.
  code39,

  /// Code 93 1D linear barcode format.
  code93,

  /// Codabar 1D linear barcode format.
  codabar,

  /// Interleaved 2 of 5 (ITF) barcode format.
  itf,

  /// Aztec 2D matrix barcode format.
  aztec,
}

extension BarcodeFormatFilterExtension on BarcodeFormatFilter {
  /// Returns string identifier used in ML Kit and ScanResult.
  String get nameString {
    switch (this) {
      case BarcodeFormatFilter.all:
        return 'ALL';
      case BarcodeFormatFilter.qrCode:
        return 'QR_CODE';
      case BarcodeFormatFilter.code128:
        return 'CODE_128';
      case BarcodeFormatFilter.pdf417:
        return 'PDF417';
      case BarcodeFormatFilter.dataMatrix:
        return 'DATA_MATRIX';
      case BarcodeFormatFilter.ean13:
        return 'EAN_13';
      case BarcodeFormatFilter.ean8:
        return 'EAN_8';
      case BarcodeFormatFilter.upcA:
        return 'UPC_A';
      case BarcodeFormatFilter.upcE:
        return 'UPC_E';
      case BarcodeFormatFilter.code39:
        return 'CODE_39';
      case BarcodeFormatFilter.code93:
        return 'CODE_93';
      case BarcodeFormatFilter.codabar:
        return 'CODABAR';
      case BarcodeFormatFilter.itf:
        return 'ITF';
      case BarcodeFormatFilter.aztec:
        return 'AZTEC';
    }
  }

  /// Parses a string representation into a [BarcodeFormatFilter].
  static BarcodeFormatFilter fromString(String value) {
    final upper = value.toUpperCase().trim();
    for (final fmt in BarcodeFormatFilter.values) {
      if (fmt.nameString == upper || fmt.name.toUpperCase() == upper) {
        return fmt;
      }
    }
    return BarcodeFormatFilter.all;
  }
}
