import 'scanner_mode.dart';

/// Represents the extracted structured data resulting from a camera or image scan.
class ScanResult {
  /// The scanning mode used during extraction.
  final ScanMode mode;

  /// The original unparsed raw text payload from the OCR or Barcode detector.
  final String rawValue;

  /// Map of key-value parsed attributes extracted from the document or code.
  final Map<String, String> fields;

  /// Flag indicating whether validation or checksum verification passed.
  final bool isValid;

  /// Detection confidence score ranging from 0.0 to 1.0.
  final double confidence;

  /// Timestamp when the scan occurred.
  final DateTime timestamp;

  /// Optional file path to captured camera frame image.
  final String? imagePath;

  /// Additional raw metadata key-values.
  final Map<String, dynamic> metadata;

  /// Creates a new [ScanResult] instance.
  ScanResult({
    required this.mode,
    required this.rawValue,
    required this.fields,
    this.isValid = true,
    this.confidence = 1.0,
    DateTime? timestamp,
    this.imagePath,
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        metadata = metadata ?? {};

  /// Serializes the scan result to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'title': mode.title,
      'rawValue': rawValue,
      'fields': fields,
      'isValid': isValid,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'metadata': metadata,
    };
  }

  /// Creates a failed or error [ScanResult] instance.
  factory ScanResult.error(ScanMode mode, String errorMessage) {
    return ScanResult(
      mode: mode,
      rawValue: errorMessage,
      fields: {'Error': errorMessage},
      isValid: false,
      confidence: 0.0,
    );
  }

  @override
  String toString() {
    return 'ScanResult(mode: ${mode.name}, isValid: $isValid, fieldsCount: ${fields.length})';
  }
}
