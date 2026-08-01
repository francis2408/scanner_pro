import 'scanner_mode.dart';

class ScanResult {
  final ScanMode mode;
  final String rawValue;
  final Map<String, String> fields;
  final bool isValid;
  final double confidence;
  final DateTime timestamp;
  final String? imagePath;
  final Map<String, dynamic> metadata;

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
