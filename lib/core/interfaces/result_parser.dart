import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Abstract interface for all result parsers (MRZ, VIN, Aadhaar, PAN, etc.).
///
/// Standardizes the parse input/output contract across all document-specific
/// parsers in the framework, enabling:
/// - Consistent error handling
/// - Pluggable parser registration
/// - Unified confidence scoring
/// - Structured validation results
abstract class ResultParser {
  /// Human-readable name of this parser (e.g., 'MRZ Passport Parser').
  String get name;

  /// The primary scan mode this parser handles.
  ScanMode get mode;

  /// Additional scan modes this parser can also handle as fallback.
  Set<ScanMode> get additionalModes => const {};

  /// Whether this parser can attempt to parse the given raw text.
  ///
  /// Performs a quick heuristic check without full parsing.
  /// Used for auto-detection when scan mode is ambiguous.
  bool canParse(String rawText);

  /// Parses raw text or payload into a structured [ScanResult].
  ///
  /// [rawText] — The raw OCR text, barcode value, or structured payload.
  ///
  /// Returns a [ScanResult] with extracted fields, validation status,
  /// and confidence score.
  ScanResult parse(String rawText);

  /// Validates an already-parsed result and returns detailed validation info.
  ///
  /// [result] — A previously parsed [ScanResult].
  ///
  /// Returns a [ParserValidation] with per-field validation details.
  ParserValidation validate(ScanResult result);
}

/// Detailed validation result from a [ResultParser].
class ParserValidation {
  /// Overall validation passed.
  final bool isValid;

  /// Overall confidence (0.0–1.0).
  final double confidence;

  /// Per-field validation results.
  final Map<String, FieldValidation> fieldValidations;

  /// Human-readable validation summary.
  final String summary;

  /// List of validation warnings (non-critical issues).
  final List<String> warnings;

  /// List of validation errors (critical failures).
  final List<String> errors;

  const ParserValidation({
    required this.isValid,
    required this.confidence,
    this.fieldValidations = const {},
    this.summary = '',
    this.warnings = const [],
    this.errors = const [],
  });

  /// Creates a passing validation result.
  factory ParserValidation.passed({
    double confidence = 1.0,
    Map<String, FieldValidation>? fields,
  }) {
    return ParserValidation(
      isValid: true,
      confidence: confidence,
      fieldValidations: fields ?? const {},
      summary: 'All validations passed.',
    );
  }

  /// Creates a failing validation result.
  factory ParserValidation.failed({
    required List<String> errors,
    double confidence = 0.0,
    Map<String, FieldValidation>? fields,
  }) {
    return ParserValidation(
      isValid: false,
      confidence: confidence,
      fieldValidations: fields ?? const {},
      errors: errors,
      summary: 'Validation failed: ${errors.join(', ')}',
    );
  }
}

/// Validation result for a single parsed field.
class FieldValidation {
  /// Field name.
  final String fieldName;

  /// Whether this field passed validation.
  final bool isValid;

  /// Confidence for this field (0.0–1.0).
  final double confidence;

  /// The validated/corrected value (may differ from raw value after OCR correction).
  final String? correctedValue;

  /// Validation method used (e.g., 'checksum', 'regex', 'lookup', 'length').
  final String validationMethod;

  /// Validation message.
  final String message;

  const FieldValidation({
    required this.fieldName,
    required this.isValid,
    this.confidence = 1.0,
    this.correctedValue,
    this.validationMethod = '',
    this.message = '',
  });
}
