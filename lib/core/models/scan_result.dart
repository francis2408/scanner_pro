import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  /// Optional raw byte buffer of the scanned image frame.
  final Uint8List? rawBytes;

  /// Detected barcode format or document type specification.
  final String? format;

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
    this.roi,
    List<String>? enhancementsApplied,
    this.isDuplicate = false,
    this.corners,
    this.boundingBox,
    this.imageSize,
    this.scanDuration,
    Map<String, dynamic>? metadata,
  })  : timestamp = timestamp ?? DateTime.now(),
        enhancementsApplied = enhancementsApplied ?? const [],
        metadata = metadata ?? {};

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
    Rect? roi,
    List<String>? enhancementsApplied,
    bool? isDuplicate,
    List<Offset>? corners,
    Rect? boundingBox,
    Size? imageSize,
    Duration? scanDuration,
    Map<String, dynamic>? metadata,
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
      roi: roi ?? this.roi,
      enhancementsApplied: enhancementsApplied ?? this.enhancementsApplied,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      corners: corners ?? this.corners,
      boundingBox: boundingBox ?? this.boundingBox,
      imageSize: imageSize ?? this.imageSize,
      scanDuration: scanDuration ?? this.scanDuration,
      metadata: metadata ?? this.metadata,
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
    return 'ScanResult(mode: ${mode.name}, isValid: $isValid, confidence: $confidence, format: $format, fieldsCount: ${fields.length}, duration: ${scanDuration?.inMilliseconds ?? 0}ms)';
  }
}


