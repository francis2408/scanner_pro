import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Abstract interface for all scan detection backends.
///
/// This interface enables swappable detection engines (ML Kit, TFLite, custom Dart)
/// while maintaining a consistent API contract across the framework.
///
/// Inspired by the plugin architecture patterns of Google ML Kit, Dynamsoft, and
/// Scanbot SDK where detection backends are interchangeable.
abstract class ScanDetector {
  /// Human-readable name of this detector (e.g., 'MLKitBarcodeDetector').
  String get name;

  /// Whether this detector is initialized and ready to process frames.
  bool get isReady;

  /// Set of scan modes this detector supports.
  Set<ScanMode> get supportedModes;

  /// Priority level for fallback chain ordering (higher = tried first).
  int get priority => 0;

  /// Initializes the detector and allocates any required resources.
  ///
  /// This may involve loading ML models, initializing native plugins, etc.
  /// Must be called before [detect] or [detectBytes].
  Future<void> initialize();

  /// Detects and processes a frame from a camera image input.
  ///
  /// [inputImage] — Platform-specific camera image (e.g., `InputImage` from ML Kit).
  /// [mode] — The scan mode to apply.
  /// [roi] — Optional region of interest (normalized 0.0–1.0 coordinates).
  ///
  /// Returns a [DetectionResult] containing raw detection data.
  Future<DetectionResult> detect(
    dynamic inputImage,
    ScanMode mode, {
    Rect? roi,
  });

  /// Detects and processes a raw byte buffer.
  ///
  /// [bytes] — Raw image bytes (grayscale or RGBA depending on detector).
  /// [width], [height] — Image dimensions.
  /// [mode] — The scan mode to apply.
  ///
  /// Returns a [DetectionResult] containing raw detection data.
  Future<DetectionResult> detectBytes(
    Uint8List bytes,
    int width,
    int height,
    ScanMode mode,
  );

  /// Releases all resources held by this detector.
  ///
  /// After calling dispose, [isReady] must return false and [detect]/[detectBytes]
  /// should throw if called.
  Future<void> dispose();
}

/// Raw detection result from a [ScanDetector].
///
/// Contains the unprocessed output from the detection backend, before
/// any parsing, validation, or post-processing is applied.
class DetectionResult {
  /// The scan mode that produced this result.
  final ScanMode mode;

  /// Name of the detector that produced this result.
  final String detectorName;

  /// Whether detection found any valid content.
  final bool hasContent;

  /// Raw text payload (for OCR, MRZ, barcode value, etc.).
  final String rawText;

  /// Detection confidence (0.0–1.0).
  final double confidence;

  /// Individual barcode detection results (for barcode/QR modes).
  final List<BarcodeResult> barcodes;

  /// Detected bounding boxes in image coordinates.
  final List<Rect> boundingBoxes;

  /// Detected corner points in image coordinates.
  final List<List<Offset>> cornerSets;

  /// Raw detection metadata from the backend.
  final Map<String, dynamic> metadata;

  /// Time taken for detection.
  final Duration detectionTime;

  const DetectionResult({
    required this.mode,
    required this.detectorName,
    this.hasContent = false,
    this.rawText = '',
    this.confidence = 0.0,
    this.barcodes = const [],
    this.boundingBoxes = const [],
    this.cornerSets = const [],
    this.metadata = const {},
    this.detectionTime = Duration.zero,
  });

  /// Creates an empty detection result (no content found).
  factory DetectionResult.empty(ScanMode mode, String detectorName) {
    return DetectionResult(
      mode: mode,
      detectorName: detectorName,
      hasContent: false,
    );
  }
}
