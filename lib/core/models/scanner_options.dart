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

/// State representing camera frame processing activity level.
enum ScannerFpsState {
  /// Active searching state for codes/documents (30 FPS / ~33ms).
  searching,

  /// Target code/document detected (15 FPS / ~66ms).
  detected,

  /// Idle / low-activity state (10 FPS / ~100ms).
  idle,
}

extension ScannerFpsStateExtension on ScannerFpsState {
  int get targetFps {
    switch (this) {
      case ScannerFpsState.searching:
        return 30;
      case ScannerFpsState.detected:
        return 15;
      case ScannerFpsState.idle:
        return 10;
    }
  }

  int get frameIntervalMs {
    switch (this) {
      case ScannerFpsState.searching:
        return 33;
      case ScannerFpsState.detected:
        return 66;
      case ScannerFpsState.idle:
        return 100;
    }
  }
}

/// Dynamic Region of Interest (ROI) scanning window rectangle.
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

  /// Target frame processing rate in frames per second (e.g. 15-30 FPS).
  final int targetFrameRate;

  /// Dynamically adjust frame processing rate based on detection state (Searching: 30 FPS, Detected: 15 FPS, Idle: 10 FPS).
  final bool enableAdaptiveFps;

  /// Dynamically adjust frame skipping based on device processing load & latency.
  final bool enableAdaptiveFrameSkipping;

  /// Automatically skip vision engine analysis when scene remains static.
  final bool enablePauseOnStaticFrame;

  /// Enable progressive camera resolution escalation (640x480 -> 1280x720 -> 1920x1080).
  final bool enableProgressiveResolution;

  /// Timeout duration during which identical scanned payloads are ignored.
  final Duration duplicateTimeout;

  /// Whether duplicate filtering is enabled.
  final bool enableDuplicateFilter;

  /// Enable in-memory LRU detection cache to bypass duplicate frame decoding.
  final bool enableDetectionCache;

  /// Timeout duration for detection cache entries.
  final Duration detectionCacheTimeout;

  /// Maximum frame buffer queue size to prevent memory backlog.
  final int frameQueueCapacity;

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

  /// Optional explicit pixel/coordinate scan rectangle restriction area.
  final Rect? rectScanArea;

  /// Optional whitelist of allowed barcode format symbologies (e.g. ['QR_CODE', 'EAN_13', 'PDF417']).
  final List<String>? allowedFormats;

  /// Whether audio beep feedback is emitted on scan success/failure.
  final bool enableSound;

  /// Whether haptic vibration feedback is triggered on scan success/failure.
  final bool enableVibration;

  /// Flashlight torch intensity brightness level (0.0 to 1.0).
  final double torchLevel;

  /// Whether camera focus is currently locked to prevent hunting.
  final bool isFocusLocked;

  /// Whether enterprise document auto capture is enabled when quality threshold is met.
  final bool enableAutoCapture;

  /// Quality score threshold (0.0 to 1.0) required to trigger auto capture.
  final double autoCaptureQualityThreshold;

  /// Number of consecutive stable high-quality frames required for auto capture.
  final int autoCaptureSteadyFrames;

  /// Whether multi-frame temporal consensus voting is enabled to achieve 98-99% OCR accuracy.
  final bool enableMultiFrameConsensus;

  /// Number of sequential frames accumulated for temporal consensus voting.
  final int consensusFrameCount;

  /// Target accuracy confidence threshold (e.g. 0.98 = 98%) required for consensus emission.
  final double consensusAccuracyThreshold;

  /// Dynamic Region of Interest (ROI) adjustment based on detected target bounding box.
  final bool enableAdaptiveRoi;

  /// Explicit pixel area ROI scan bounds (alias for [rectScanArea]).
  Rect? get scanArea => rectScanArea;

  /// Alias getter for duplicate filter setting (inverted).
  bool get allowDuplicates => !enableDuplicateFilter;

  /// Alias getter for duplicate timeout delay.
  Duration get duplicateDelay => duplicateTimeout;

  /// Constructs a [ScannerOptions] instance.
  const ScannerOptions({
    this.scanStrategy = ScanStrategy.continuous,
    this.scanWindow = ScanWindow.centerReticle,
    this.frameThrottleMs = 50,
    this.targetFrameRate = 20,
    this.enableAdaptiveFps = true,
    this.enableAdaptiveFrameSkipping = true,
    this.enablePauseOnStaticFrame = true,
    this.enableProgressiveResolution = true,
    this.duplicateTimeout = const Duration(milliseconds: 2000),
    this.enableDuplicateFilter = true,
    this.enableDetectionCache = true,
    this.detectionCacheTimeout = const Duration(milliseconds: 2000),
    this.frameQueueCapacity = 3,
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
    this.rectScanArea,
    this.allowedFormats,
    this.enableSound = true,
    this.enableVibration = true,
    this.torchLevel = 1.0,
    this.isFocusLocked = false,
    this.enableAutoCapture = true,
    this.autoCaptureQualityThreshold = 0.85,
    this.autoCaptureSteadyFrames = 3,
    this.enableMultiFrameConsensus = true,
    this.consensusFrameCount = 3,
    this.consensusAccuracyThreshold = 0.98,
    this.enableAdaptiveRoi = true,
  });

  /// Factory constructor supporting explicit [scanArea], [allowDuplicates], and [duplicateDelay] parameters.
  factory ScannerOptions.custom({
    ScanStrategy scanStrategy = ScanStrategy.continuous,
    ScanWindow? scanWindow = ScanWindow.centerReticle,
    Rect? scanArea,
    bool? allowDuplicates,
    Duration? duplicateDelay,
    int frameThrottleMs = 50,
    int targetFrameRate = 20,
    bool enableAdaptiveFps = true,
    bool enableAdaptiveFrameSkipping = true,
    bool enablePauseOnStaticFrame = true,
    bool enableProgressiveResolution = true,
    Duration duplicateTimeout = const Duration(milliseconds: 2000),
    bool enableDuplicateFilter = true,
    bool enableDetectionCache = true,
    Duration detectionCacheTimeout = const Duration(milliseconds: 2000),
    int frameQueueCapacity = 3,
    bool enableIsolateProcessing = true,
    bool enableImageEnhancement = true,
    bool enableBlurDetection = true,
    bool enableAutoBrightnessCheck = true,
    bool autoTorchInLowLight = false,
    double lowLightThreshold = 0.25,
    bool enableAutoZoom = true,
    bool autoResetZoomAfterScan = true,
    double autoZoomThreshold = 0.15,
    bool continuousAutofocus = true,
    bool enableMultiCodeDetection = true,
    int maxMultiCodeCount = 10,
    bool enableScanHistory = true,
    int maxHistorySize = 50,
    int? maxBatchCount,
    double minConfidence = 0.70,
    List<String>? allowedFormats,
    bool enableSound = true,
    bool enableVibration = true,
    double torchLevel = 1.0,
    bool isFocusLocked = false,
    bool enableAutoCapture = true,
    double autoCaptureQualityThreshold = 0.85,
    int autoCaptureSteadyFrames = 3,
    bool enableMultiFrameConsensus = true,
    int consensusFrameCount = 3,
    double consensusAccuracyThreshold = 0.98,
    bool enableAdaptiveRoi = true,
  }) {
    return ScannerOptions(
      scanStrategy: scanStrategy,
      scanWindow: scanWindow,
      rectScanArea: scanArea,
      duplicateTimeout: duplicateDelay ?? duplicateTimeout,
      enableDuplicateFilter:
          allowDuplicates != null ? !allowDuplicates : enableDuplicateFilter,
      frameThrottleMs: frameThrottleMs,
      targetFrameRate: targetFrameRate,
      enableAdaptiveFps: enableAdaptiveFps,
      enableAdaptiveFrameSkipping: enableAdaptiveFrameSkipping,
      enablePauseOnStaticFrame: enablePauseOnStaticFrame,
      enableProgressiveResolution: enableProgressiveResolution,
      enableDetectionCache: enableDetectionCache,
      detectionCacheTimeout: detectionCacheTimeout,
      frameQueueCapacity: frameQueueCapacity,
      enableIsolateProcessing: enableIsolateProcessing,
      enableImageEnhancement: enableImageEnhancement,
      enableBlurDetection: enableBlurDetection,
      enableAutoBrightnessCheck: enableAutoBrightnessCheck,
      autoTorchInLowLight: autoTorchInLowLight,
      lowLightThreshold: lowLightThreshold,
      enableAutoZoom: enableAutoZoom,
      autoResetZoomAfterScan: autoResetZoomAfterScan,
      autoZoomThreshold: autoZoomThreshold,
      continuousAutofocus: continuousAutofocus,
      enableMultiCodeDetection: enableMultiCodeDetection,
      maxMultiCodeCount: maxMultiCodeCount,
      enableScanHistory: enableScanHistory,
      maxHistorySize: maxHistorySize,
      maxBatchCount: maxBatchCount,
      minConfidence: minConfidence,
      allowedFormats: allowedFormats,
      enableSound: enableSound,
      enableVibration: enableVibration,
      torchLevel: torchLevel,
      isFocusLocked: isFocusLocked,
      enableAutoCapture: enableAutoCapture,
      autoCaptureQualityThreshold: autoCaptureQualityThreshold,
      autoCaptureSteadyFrames: autoCaptureSteadyFrames,
      enableMultiFrameConsensus: enableMultiFrameConsensus,
      consensusFrameCount: consensusFrameCount,
      consensusAccuracyThreshold: consensusAccuracyThreshold,
      enableAdaptiveRoi: enableAdaptiveRoi,
    );
  }

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
    enableSound: true,
    enableVibration: true,
    enableAutoCapture: true,
    enableMultiFrameConsensus: true,
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
    enableSound: false,
    enableVibration: true,
    enableAutoCapture: false,
    enableMultiFrameConsensus: false,
  );

  ScannerOptions copyWith({
    ScanStrategy? scanStrategy,
    ScanWindow? scanWindow,
    int? frameThrottleMs,
    int? targetFrameRate,
    bool? enableAdaptiveFps,
    bool? enableAdaptiveFrameSkipping,
    bool? enablePauseOnStaticFrame,
    bool? enableProgressiveResolution,
    Duration? duplicateTimeout,
    bool? enableDuplicateFilter,
    bool? enableDetectionCache,
    Duration? detectionCacheTimeout,
    int? frameQueueCapacity,
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
    Rect? rectScanArea,
    List<String>? allowedFormats,
    bool? enableSound,
    bool? enableVibration,
    double? torchLevel,
    bool? isFocusLocked,
    bool? enableAutoCapture,
    double? autoCaptureQualityThreshold,
    int? autoCaptureSteadyFrames,
    bool? enableMultiFrameConsensus,
    int? consensusFrameCount,
    double? consensusAccuracyThreshold,
    bool? enableAdaptiveRoi,
  }) {
    return ScannerOptions(
      scanStrategy: scanStrategy ?? this.scanStrategy,
      scanWindow: scanWindow ?? this.scanWindow,
      frameThrottleMs: frameThrottleMs ?? this.frameThrottleMs,
      targetFrameRate: targetFrameRate ?? this.targetFrameRate,
      enableAdaptiveFps: enableAdaptiveFps ?? this.enableAdaptiveFps,
      enableAdaptiveFrameSkipping:
          enableAdaptiveFrameSkipping ?? this.enableAdaptiveFrameSkipping,
      enablePauseOnStaticFrame:
          enablePauseOnStaticFrame ?? this.enablePauseOnStaticFrame,
      enableProgressiveResolution:
          enableProgressiveResolution ?? this.enableProgressiveResolution,
      duplicateTimeout: duplicateTimeout ?? this.duplicateTimeout,
      enableDuplicateFilter:
          enableDuplicateFilter ?? this.enableDuplicateFilter,
      enableDetectionCache: enableDetectionCache ?? this.enableDetectionCache,
      detectionCacheTimeout:
          detectionCacheTimeout ?? this.detectionCacheTimeout,
      frameQueueCapacity: frameQueueCapacity ?? this.frameQueueCapacity,
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
      rectScanArea: rectScanArea ?? this.rectScanArea,
      allowedFormats: allowedFormats ?? this.allowedFormats,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      torchLevel: torchLevel ?? this.torchLevel,
      isFocusLocked: isFocusLocked ?? this.isFocusLocked,
      enableAutoCapture: enableAutoCapture ?? this.enableAutoCapture,
      autoCaptureQualityThreshold:
          autoCaptureQualityThreshold ?? this.autoCaptureQualityThreshold,
      autoCaptureSteadyFrames:
          autoCaptureSteadyFrames ?? this.autoCaptureSteadyFrames,
      enableMultiFrameConsensus:
          enableMultiFrameConsensus ?? this.enableMultiFrameConsensus,
      consensusFrameCount: consensusFrameCount ?? this.consensusFrameCount,
      consensusAccuracyThreshold:
          consensusAccuracyThreshold ?? this.consensusAccuracyThreshold,
      enableAdaptiveRoi: enableAdaptiveRoi ?? this.enableAdaptiveRoi,
    );
  }
}
