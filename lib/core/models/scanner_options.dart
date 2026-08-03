import 'package:flutter/material.dart';

/// Operational strategy for handling scan results.
enum ScanStrategy {
  /// Stops processing live frames upon the first valid result.
  single,

  /// Continually emits valid scan results while staying active.
  continuous,

  /// Accumulates scanned results into a session batch list (Inventory Mode).
  batch,
}

/// Represents a normalized Region of Interest (ROI) scanning window rectangle.
/// Values range from 0.0 to 1.0 relative to total camera frame dimensions.
class ScanWindow {
  final double left;
  final double top;
  final double width;
  final double height;

  const ScanWindow({
    this.left = 0.0,
    this.top = 0.0,
    this.width = 1.0,
    this.height = 1.0,
  });

  /// Full camera frame window preset.
  static const ScanWindow fullFrame = ScanWindow(
    left: 0.0,
    top: 0.0,
    width: 1.0,
    height: 1.0,
  );

  /// Center reticle window preset.
  static const ScanWindow centerReticle = ScanWindow(
    left: 0.1,
    top: 0.2,
    width: 0.8,
    height: 0.6,
  );

  /// Converts normalized coordinates to pixel [Rect] based on overall frame size.
  Rect toPixelRect(Size frameSize) {
    return Rect.fromLTWH(
      left * frameSize.width,
      top * frameSize.height,
      width * frameSize.width,
      height * frameSize.height,
    );
  }
}

/// Configuration options controlling camera detection rate, ROI bounds,
/// duplicate caching, auto-zoom, image enhancement, isolate multi-threading,
/// and enterprise scanning parameters.
class ScannerOptions {
  /// Active result handling strategy (single, continuous, batch).
  final ScanStrategy scanStrategy;

  /// Restrict image analysis strictly to this sub-region cutout (ROI).
  final ScanWindow? scanWindow;

  /// Minimum delay in milliseconds between consecutive frame analysis passes.
  /// (e.g. 50ms = max 20 detections/sec for optimal CPU & battery usage).
  final int frameThrottleMs;

  /// Target frame processing rate in frames per second (e.g. 15-20 FPS).
  final int targetFrameRate;

  /// Dynamically adjust frame skipping based on device processing load & latency.
  final bool enableAdaptiveFrameSkipping;

  /// Automatically skip vision engine analysis when scene remains static.
  final bool enablePauseOnStaticFrame;

  /// Timeout duration during which identical scanned payloads are ignored.
  final Duration duplicateTimeout;

  /// Whether duplicate filtering is enabled.
  final bool enableDuplicateFilter;

  /// Offload YUV/NV21 image conversions, ROI cropping, and image enhancement to background isolate.
  final bool enableIsolateProcessing;

  /// Apply brightness normalization, contrast enhancement, sharpening, and denoising in isolate.
  final bool enableImageEnhancement;

  /// Evaluate frame sharpness score to trigger auto-refocus if blurred.
  final bool enableBlurDetection;

  /// Analyze frame luminosity and emit low-light alert if below threshold.
  final bool enableAutoBrightnessCheck;

  /// Automatically switch flashlight on when ambient light drops below threshold.
  final bool autoTorchInLowLight;

  /// Normalized ambient luminosity threshold (0.0 to 1.0) for low-light detection.
  final double lowLightThreshold;

  /// Automatically trigger digital camera zoom when small barcodes are detected far away.
  final bool enableAutoZoom;

  /// Automatically reset digital zoom back to 1.0x after successful scan emission.
  final bool autoResetZoomAfterScan;

  /// Code-to-viewport area ratio below which auto-zoom triggers (e.g., 0.15 = 15%).
  final double autoZoomThreshold;

  /// Whether continuous autofocus mode is enabled.
  final bool continuousAutofocus;

  /// Allow detecting multiple barcodes/QR codes in a single image pass.
  final bool enableMultiCodeDetection;

  /// Maximum number of codes to return in a multi-code pass.
  final int maxMultiCodeCount;

  /// Retain in-memory log of recent scan results.
  final bool enableScanHistory;

  /// Maximum scan history capacity.
  final int maxHistorySize;

  /// Optional maximum items limit in batch inventory mode.
  final int? maxBatchCount;

  /// Minimum confidence required to accept a scan result (0.0 to 1.0).
  final double minConfidence;

  /// Constructs a [ScannerOptions] instance.
  const ScannerOptions({
    this.scanStrategy = ScanStrategy.continuous,
    this.scanWindow = ScanWindow.centerReticle,
    this.frameThrottleMs = 50,
    this.targetFrameRate = 20,
    this.enableAdaptiveFrameSkipping = true,
    this.enablePauseOnStaticFrame = true,
    this.duplicateTimeout = const Duration(milliseconds: 1000),
    this.enableDuplicateFilter = true,
    this.enableIsolateProcessing = true,
    this.enableImageEnhancement = true,
    this.enableBlurDetection = true,
    this.enableAutoBrightnessCheck = true,
    this.autoTorchInLowLight = false,
    this.lowLightThreshold = 0.25,
    this.enableAutoZoom = true,
    this.autoResetZoomAfterScan = true,
    this.autoZoomThreshold = 0.15,
    this.continuousAutofocus = true,
    this.enableMultiCodeDetection = true,
    this.maxMultiCodeCount = 10,
    this.enableScanHistory = true,
    this.maxHistorySize = 50,
    this.maxBatchCount,
    this.minConfidence = 0.70,
  });

  /// High-performance preset optimized for speed and low CPU consumption.
  static const ScannerOptions highPerformance = ScannerOptions(
    scanStrategy: ScanStrategy.continuous,
    scanWindow: ScanWindow.centerReticle,
    frameThrottleMs: 50,
    targetFrameRate: 20,
    enableAdaptiveFrameSkipping: true,
    enablePauseOnStaticFrame: true,
    duplicateTimeout: Duration(milliseconds: 1000),
    enableDuplicateFilter: true,
    enableIsolateProcessing: true,
    enableImageEnhancement: true,
    enableBlurDetection: true,
    enableAutoBrightnessCheck: true,
    enableAutoZoom: true,
  );

  /// Battery-saver preset for background/inventory batch scanning.
  static const ScannerOptions batterySaver = ScannerOptions(
    scanStrategy: ScanStrategy.batch,
    scanWindow: ScanWindow.centerReticle,
    frameThrottleMs: 150,
    targetFrameRate: 10,
    enableAdaptiveFrameSkipping: true,
    enablePauseOnStaticFrame: true,
    duplicateTimeout: Duration(milliseconds: 1500),
    enableDuplicateFilter: true,
    enableIsolateProcessing: true,
    enableImageEnhancement: false,
    enableBlurDetection: false,
    enableAutoBrightnessCheck: false,
    enableAutoZoom: false,
  );

  ScannerOptions copyWith({
    ScanStrategy? scanStrategy,
    ScanWindow? scanWindow,
    int? frameThrottleMs,
    int? targetFrameRate,
    bool? enableAdaptiveFrameSkipping,
    bool? enablePauseOnStaticFrame,
    Duration? duplicateTimeout,
    bool? enableDuplicateFilter,
    bool? enableIsolateProcessing,
    bool? enableImageEnhancement,
    bool? enableBlurDetection,
    bool? enableAutoBrightnessCheck,
    bool? autoTorchInLowLight,
    double? lowLightThreshold,
    bool? enableAutoZoom,
    bool? autoResetZoomAfterScan,
    double? autoZoomThreshold,
    bool? continuousAutofocus,
    bool? enableMultiCodeDetection,
    int? maxMultiCodeCount,
    bool? enableScanHistory,
    int? maxHistorySize,
    int? maxBatchCount,
    double? minConfidence,
  }) {
    return ScannerOptions(
      scanStrategy: scanStrategy ?? this.scanStrategy,
      scanWindow: scanWindow ?? this.scanWindow,
      frameThrottleMs: frameThrottleMs ?? this.frameThrottleMs,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      enableAdaptiveFrameSkipping:
          enableAdaptiveFrameSkipping ?? this.enableAdaptiveFrameSkipping,
      enablePauseOnStaticFrame:
          enablePauseOnStaticFrame ?? this.enablePauseOnStaticFrame,
      duplicateTimeout: duplicateTimeout ?? this.duplicateTimeout,
      enableDuplicateFilter:
          enableDuplicateFilter ?? this.enableDuplicateFilter,
      enableIsolateProcessing:
          enableIsolateProcessing ?? this.enableIsolateProcessing,
      enableImageEnhancement:
          enableImageEnhancement ?? this.enableImageEnhancement,
      enableBlurDetection: enableBlurDetection ?? this.enableBlurDetection,
      enableAutoBrightnessCheck:
          enableAutoBrightnessCheck ?? this.enableAutoBrightnessCheck,
      autoTorchInLowLight: autoTorchInLowLight ?? this.autoTorchInLowLight,
      lowLightThreshold: lowLightThreshold ?? this.lowLightThreshold,
      enableAutoZoom: enableAutoZoom ?? this.enableAutoZoom,
      autoResetZoomAfterScan:
          autoResetZoomAfterScan ?? this.autoResetZoomAfterScan,
      autoZoomThreshold: autoZoomThreshold ?? this.autoZoomThreshold,
      continuousAutofocus: continuousAutofocus ?? this.continuousAutofocus,
      enableMultiCodeDetection:
          enableMultiCodeDetection ?? this.enableMultiCodeDetection,
      maxMultiCodeCount: maxMultiCodeCount ?? this.maxMultiCodeCount,
      enableScanHistory: enableScanHistory ?? this.enableScanHistory,
      maxHistorySize: maxHistorySize ?? this.maxHistorySize,
      maxBatchCount: maxBatchCount ?? this.maxBatchCount,
      minConfidence: minConfidence ?? this.minConfidence,
    );
  }
}
