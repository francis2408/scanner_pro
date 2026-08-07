import 'dart:typed_data';

import '../models/scanner_mode.dart';

/// Abstract interface for pluggable frame preprocessing chains.
///
/// Allows different preprocessing strategies to be composed and swapped
/// based on scan mode, lighting conditions, and content type.
///
/// The preprocessing pipeline runs in a background isolate before
/// detection, enhancing the image for optimal recognition accuracy.
abstract class FramePreprocessor {
  /// Human-readable name of this preprocessor.
  String get name;

  /// Whether this preprocessor can handle the given scan mode.
  bool canHandle(ScanMode mode);

  /// Priority for ordering in a preprocessing chain (higher = runs first).
  int get priority => 0;

  /// Processes a raw grayscale frame and returns the enhanced result.
  ///
  /// [gray] — Single-channel grayscale pixel buffer.
  /// [width], [height] — Image dimensions.
  /// [context] — Preprocessing context with current image metrics.
  ///
  /// Returns a [PreprocessedFrame] containing the processed image and metadata.
  PreprocessedFrame process(
    Uint8List gray,
    int width,
    int height,
    PreprocessingContext context,
  );
}

/// Context provided to [FramePreprocessor] with current image analysis metrics.
class PreprocessingContext {
  /// Normalized average luminosity (0.0–1.0).
  final double luminosity;

  /// Blur score from Laplacian variance (higher = sharper).
  final double blurScore;

  /// Contrast ratio (0.0–1.0).
  final double contrastScore;

  /// Current scan mode.
  final ScanMode mode;

  /// Whether torch/flash is currently enabled.
  final bool torchEnabled;

  /// Whether this is the first frame in a new scanning session.
  final bool isFirstFrame;

  /// Frame index in the current session.
  final int frameIndex;

  const PreprocessingContext({
    required this.luminosity,
    required this.blurScore,
    required this.contrastScore,
    required this.mode,
    this.torchEnabled = false,
    this.isFirstFrame = false,
    this.frameIndex = 0,
  });
}

/// Result of frame preprocessing.
class PreprocessedFrame {
  /// Processed grayscale image bytes.
  final Uint8List bytes;

  /// Image width (may differ from input if resized).
  final int width;

  /// Image height (may differ from input if resized).
  final int height;

  /// Name of the preprocessing strategy applied.
  final String strategyName;

  /// Ordered list of processing steps applied.
  final List<String> stepsApplied;

  /// Updated image metrics after preprocessing.
  final PreprocessingMetrics metrics;

  const PreprocessedFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.strategyName,
    this.stepsApplied = const [],
    required this.metrics,
  });
}

/// Image quality metrics after preprocessing.
class PreprocessingMetrics {
  /// Updated luminosity after enhancement.
  final double luminosity;

  /// Updated blur score after sharpening.
  final double blurScore;

  /// Updated contrast score after enhancement.
  final double contrastScore;

  /// Estimated noise level (0.0–1.0).
  final double noiseLevel;

  const PreprocessingMetrics({
    required this.luminosity,
    required this.blurScore,
    required this.contrastScore,
    this.noiseLevel = 0.0,
  });
}
