import 'scanner_mode.dart';
import 'scanner_options.dart';

/// Comprehensive configuration for the frame processing pipeline.
///
/// Controls every stage of frame processing from capture through detection,
/// with mode-specific overrides and quality gates.
class FramePipelineConfig {
  /// Preprocessing strategy to apply.
  final PreprocessingStrategy preprocessing;

  /// Quality gates that frames must pass before detection.
  final QualityGateConfig qualityGate;

  /// Detection backend configuration.
  final DetectionConfig detection;

  /// Post-processing configuration.
  final PostProcessingConfig postProcessing;

  /// Scan window (ROI) configuration.
  final ScanWindow? scanWindow;

  /// Maximum frames per second to process.
  final int maxFps;

  /// Whether to skip static (unchanged) frames.
  final bool skipStaticFrames;

  /// Whether to enable multi-pass OCR.
  final bool enableMultiPassOcr;

  /// Whether to enable barcode fallback decoder.
  final bool enableBarcodeFallback;

  const FramePipelineConfig({
    this.preprocessing = const PreprocessingStrategy(),
    this.qualityGate = const QualityGateConfig(),
    this.detection = const DetectionConfig(),
    this.postProcessing = const PostProcessingConfig(),
    this.scanWindow,
    this.maxFps = 15,
    this.skipStaticFrames = true,
    this.enableMultiPassOcr = true,
    this.enableBarcodeFallback = true,
  });

  /// Creates a pipeline config optimized for the given scan mode.
  factory FramePipelineConfig.forMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.qr:
      case ScanMode.barcode:
      case ScanMode.multiCode:
        return const FramePipelineConfig(
          preprocessing: PreprocessingStrategy(
            enableBinarization: true,
            binarizationType: BinarizationType.otsu,
            enableNoiseReduction: false,
          ),
          qualityGate: QualityGateConfig(
            minBlurScore: 30.0,
            enableGlareDetection: false,
          ),
          maxFps: 20,
          enableMultiPassOcr: false,
          enableBarcodeFallback: true,
        );

      case ScanMode.document:
        return const FramePipelineConfig(
          preprocessing: PreprocessingStrategy(
            enableEdgeDetection: true,
            enableNoiseReduction: true,
            noiseReductionStrength: 0.5,
          ),
          qualityGate: QualityGateConfig(
            minBlurScore: 60.0,
            minCoverageRatio: 0.2,
            enableGlareDetection: true,
          ),
          maxFps: 10,
          enableMultiPassOcr: false,
        );

      case ScanMode.ocr:
      case ScanMode.invoice:
      case ScanMode.receipt:
      case ScanMode.businessCard:
        return const FramePipelineConfig(
          preprocessing: PreprocessingStrategy(
            enableContrastEnhancement: true,
            enableSharpening: true,
            enableBinarization: true,
            binarizationType: BinarizationType.sauvola,
          ),
          qualityGate: QualityGateConfig(
            minBlurScore: 50.0,
            minContrastRatio: 0.25,
          ),
          maxFps: 12,
          enableMultiPassOcr: true,
        );

      case ScanMode.passport:
      case ScanMode.vin:
        return const FramePipelineConfig(
          preprocessing: PreprocessingStrategy(
            enableContrastEnhancement: true,
            enableSharpening: true,
            enableBinarization: true,
            binarizationType: BinarizationType.sauvola,
          ),
          qualityGate: QualityGateConfig(
            minBlurScore: 60.0,
            minContrastRatio: 0.3,
          ),
          maxFps: 12,
          enableMultiPassOcr: true,
        );

      case ScanMode.face:
        return const FramePipelineConfig(
          preprocessing: PreprocessingStrategy(
            enableGammaCorrection: true,
            gamma: 0.7,
            enableNoiseReduction: true,
            noiseReductionStrength: 0.3,
          ),
          qualityGate: QualityGateConfig(
            minBlurScore: 40.0,
            enableGlareDetection: false,
          ),
          maxFps: 15,
          enableMultiPassOcr: false,
        );

      default:
        return const FramePipelineConfig();
    }
  }

  /// Creates a copy with overridden fields.
  FramePipelineConfig copyWith({
    PreprocessingStrategy? preprocessing,
    QualityGateConfig? qualityGate,
    DetectionConfig? detection,
    PostProcessingConfig? postProcessing,
    ScanWindow? scanWindow,
    int? maxFps,
    bool? skipStaticFrames,
    bool? enableMultiPassOcr,
    bool? enableBarcodeFallback,
  }) {
    return FramePipelineConfig(
      preprocessing: preprocessing ?? this.preprocessing,
      qualityGate: qualityGate ?? this.qualityGate,
      detection: detection ?? this.detection,
      postProcessing: postProcessing ?? this.postProcessing,
      scanWindow: scanWindow ?? this.scanWindow,
      maxFps: maxFps ?? this.maxFps,
      skipStaticFrames: skipStaticFrames ?? this.skipStaticFrames,
      enableMultiPassOcr: enableMultiPassOcr ?? this.enableMultiPassOcr,
      enableBarcodeFallback: enableBarcodeFallback ?? this.enableBarcodeFallback,
    );
  }
}

/// Quality gate configuration — frames must pass these checks before detection.
class QualityGateConfig {
  /// Minimum blur score (Laplacian variance) to proceed with detection.
  final double minBlurScore;

  /// Minimum luminosity (0.0–1.0) to proceed without torch recommendation.
  final double minLuminosity;

  /// Maximum luminosity before triggering overexposure warning.
  final double maxLuminosity;

  /// Minimum contrast ratio to proceed with detection.
  final double minContrastRatio;

  /// Minimum document coverage ratio in frame (for document mode).
  final double minCoverageRatio;

  /// Whether to check for specular glare/reflections.
  final bool enableGlareDetection;

  /// Maximum allowed motion score before skipping frame.
  final double maxMotionScore;

  const QualityGateConfig({
    this.minBlurScore = 40.0,
    this.minLuminosity = 0.08,
    this.maxLuminosity = 0.92,
    this.minContrastRatio = 0.15,
    this.minCoverageRatio = 0.1,
    this.enableGlareDetection = true,
    this.maxMotionScore = 80.0,
  });
}

/// Detection backend configuration.
class DetectionConfig {
  /// Maximum number of detection attempts per frame.
  final int maxRetries;

  /// Whether to try rotated variants if initial detection fails.
  final bool enableRotationRetry;

  /// Rotation angles to try (degrees).
  final List<int> rotationAngles;

  /// Whether to use multi-scale detection.
  final bool enableMultiScale;

  const DetectionConfig({
    this.maxRetries = 1,
    this.enableRotationRetry = false,
    this.rotationAngles = const [90, 180, 270],
    this.enableMultiScale = false,
  });
}

/// Post-processing configuration.
class PostProcessingConfig {
  /// Whether to apply OCR error corrections.
  final bool enableOcrCorrections;

  /// Whether to apply whitespace normalization.
  final bool enableWhitespaceNormalization;

  /// Whether to recalculate confidence after corrections.
  final bool recalculateConfidence;

  /// Whether to apply mode-specific post-processing.
  final bool enableModeSpecificProcessing;

  const PostProcessingConfig({
    this.enableOcrCorrections = true,
    this.enableWhitespaceNormalization = true,
    this.recalculateConfidence = true,
    this.enableModeSpecificProcessing = true,
  });
}

/// Binarization algorithm type.
enum BinarizationType {
  /// Otsu's global adaptive thresholding.
  otsu,

  /// Sauvola's local adaptive thresholding.
  sauvola,

  /// Simple fixed-threshold binarization.
  fixed,
}

/// Preprocessing strategy configuration.
class PreprocessingStrategy {
  /// Whether to apply contrast enhancement (CLAHE/histogram equalization).
  final bool enableContrastEnhancement;

  /// Whether to apply image binarization.
  final bool enableBinarization;

  /// Binarization algorithm to use.
  final BinarizationType binarizationType;

  /// Whether to apply noise reduction.
  final bool enableNoiseReduction;

  /// Noise reduction strength (0.0–1.0).
  final double noiseReductionStrength;

  /// Whether to apply edge detection.
  final bool enableEdgeDetection;

  /// Whether to apply sharpening (unsharp mask).
  final bool enableSharpening;

  /// Sharpening amount (0.5–2.0).
  final double sharpeningAmount;

  /// Whether to apply gamma correction.
  final bool enableGammaCorrection;

  /// Gamma value for correction.
  final double gamma;

  const PreprocessingStrategy({
    this.enableContrastEnhancement = false,
    this.enableBinarization = false,
    this.binarizationType = BinarizationType.otsu,
    this.enableNoiseReduction = false,
    this.noiseReductionStrength = 0.5,
    this.enableEdgeDetection = false,
    this.enableSharpening = false,
    this.sharpeningAmount = 1.0,
    this.enableGammaCorrection = false,
    this.gamma = 0.6,
  });
}
