import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'scanner_mode.dart';

/// Document image quality metrics calculated during isolate preprocessing.
class DocumentQualityScore {
  final double blurScore;
  final double brightnessScore;
  final double contrastScore;
  final double overallQuality;
  final bool isHighQuality;

  const DocumentQualityScore({
    required this.blurScore,
    required this.brightnessScore,
    required this.contrastScore,
    required this.overallQuality,
    required this.isHighQuality,
  });

  Map<String, dynamic> toJson() => {
        'blurScore': blurScore,
        'brightnessScore': brightnessScore,
        'contrastScore': contrastScore,
        'overallQuality': overallQuality,
        'isHighQuality': isHighQuality,
      };

  @override
  String toString() =>
      'DocumentQualityScore(overall: ${(overallQuality * 100).toStringAsFixed(1)}%, highQuality: $isHighQuality)';
}

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

  /// Optional raw byte buffer of the scanned image frame.
  final Uint8List? rawBytes;

  /// Detected barcode format or document type specification.
  final String? format;

  /// Classified document category string (e.g. invoice, receipt, passport, aadhaar, pan, vin).
  final String? documentCategory;

  /// Region of Interest (ROI) sub-rectangle cutout in frame pixel coordinates.
  final Rect? roi;

  /// List of image enhancement filters applied during isolate preprocessing.
  final List<String> enhancementsApplied;

  /// Whether this result was identified as a duplicate during session caching.
  final bool isDuplicate;

  /// Detected barcode or document corner points in frame pixel coordinates.
  final List<Offset>? corners;

  /// Detected bounding box rectangle in frame pixel coordinates.
  final Rect? boundingBox;

  /// Input frame or image resolution size.
  final Size? imageSize;

  /// Total execution duration elapsed during frame detection and parsing.
  final Duration? scanDuration;

  /// Additional raw metadata key-values.
  final Map<String, dynamic> metadata;

  /// List of individual scan results detected in a multi-code pass.
  final List<ScanResult>? multiResults;

  /// Calculated document quality score metrics (blur, contrast, brightness).
  final DocumentQualityScore? qualityScore;

  /// Confidence score achieved via temporal multi-frame consensus voting (up to 0.99 = 99%).
  final double? consensusConfidence;

  /// Detailed checklist of verification tests performed and their pass/fail statuses.
  final Map<String, bool> verifications;

  /// Processing algorithms and enhancements metadata applied to the input image.
  final Map<String, dynamic> preprocessingInfo;

  /// Creates a new [ScanResult] instance.
  ScanResult({
    required this.mode,
    required this.rawValue,
    required this.fields,
    this.isValid = true,
    this.confidence = 1.0,
    DateTime? timestamp,
    this.imagePath,
    this.rawBytes,
    this.format,
    this.documentCategory,
    this.roi,
    List<String>? enhancementsApplied,
    this.isDuplicate = false,
    this.corners,
    this.boundingBox,
    this.imageSize,
    this.scanDuration,
    Map<String, dynamic>? metadata,
    this.multiResults,
    this.qualityScore,
    this.consensusConfidence,
    Map<String, bool>? verifications,
    Map<String, dynamic>? preprocessingInfo,
  })  : timestamp = timestamp ?? DateTime.now(),
        enhancementsApplied = enhancementsApplied ?? const [],
        metadata = metadata ?? {},
        verifications = verifications ?? const {},
        preprocessingInfo = preprocessingInfo ?? const {};

  /// Creates a copy of [ScanResult] with updated fields.
  ScanResult copyWith({
    ScanMode? mode,
    String? rawValue,
    Map<String, String>? fields,
    bool? isValid,
    double? confidence,
    DateTime? timestamp,
    String? imagePath,
    Uint8List? rawBytes,
    String? format,
    String? documentCategory,
    Rect? roi,
    List<String>? enhancementsApplied,
    bool? isDuplicate,
    List<Offset>? corners,
    Rect? boundingBox,
    Size? imageSize,
    Duration? scanDuration,
    Map<String, dynamic>? metadata,
    List<ScanResult>? multiResults,
    DocumentQualityScore? qualityScore,
    double? consensusConfidence,
    Map<String, bool>? verifications,
    Map<String, dynamic>? preprocessingInfo,
  }) {
    return ScanResult(
      mode: mode ?? this.mode,
      rawValue: rawValue ?? this.rawValue,
      fields: fields ?? this.fields,
      isValid: isValid ?? this.isValid,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      rawBytes: rawBytes ?? this.rawBytes,
      format: format ?? this.format,
      documentCategory: documentCategory ?? this.documentCategory,
      roi: roi ?? this.roi,
      enhancementsApplied: enhancementsApplied ?? this.enhancementsApplied,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      corners: corners ?? this.corners,
      boundingBox: boundingBox ?? this.boundingBox,
      imageSize: imageSize ?? this.imageSize,
      scanDuration: scanDuration ?? this.scanDuration,
      metadata: metadata ?? this.metadata,
      multiResults: multiResults ?? this.multiResults,
      qualityScore: qualityScore ?? this.qualityScore,
      consensusConfidence: consensusConfidence ?? this.consensusConfidence,
      verifications: verifications ?? this.verifications,
      preprocessingInfo: preprocessingInfo ?? this.preprocessingInfo,
    );
  }

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
      'format': format ?? metadata['format'],
      'documentCategory': documentCategory,
      'isDuplicate': isDuplicate,
      'enhancementsApplied': enhancementsApplied,
      'corners': corners
          ?.map((c) => {'x': c.dx, 'y': c.dy})
          .toList(),
      'boundingBox': boundingBox != null
          ? {
              'left': boundingBox!.left,
              'top': boundingBox!.top,
              'width': boundingBox!.width,
              'height': boundingBox!.height,
            }
          : null,
      'roi': roi != null
          ? {
              'left': roi!.left,
              'top': roi!.top,
              'width': roi!.width,
              'height': roi!.height,
            }
          : null,
      'imageSize': imageSize != null
          ? {'width': imageSize!.width, 'height': imageSize!.height}
          : null,
      'scanDurationMs': scanDuration?.inMilliseconds,
      'metadata': metadata,
      'qualityScore': qualityScore?.toJson(),
      'consensusConfidence': consensusConfidence,
      'verifications': verifications,
      'preprocessingInfo': preprocessingInfo,
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
    return 'ScanResult(mode: ${mode.name}, isValid: $isValid, category: $documentCategory, confidence: $confidence, format: $format, fieldsCount: ${fields.length}, duration: ${scanDuration?.inMilliseconds ?? 0}ms)';
  }
}
