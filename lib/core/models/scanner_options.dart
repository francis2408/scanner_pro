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
/// duplicate caching, auto-zoom, and isolate multi-threading.
class ScannerOptions {
  /// Active result handling strategy (single, continuous, batch).
  final ScanStrategy scanStrategy;

  /// Restrict image analysis strictly to this sub-region cutout (ROI).
  final ScanWindow? scanWindow;

  /// Minimum delay in milliseconds between consecutive frame analysis passes.
  /// (e.g. 100ms = max 10 detections/sec for optimal CPU & battery usage).
  final int frameThrottleMs;

  /// Timeout duration during which identical scanned payloads are ignored.
  final Duration duplicateTimeout;

  /// Whether duplicate filtering is enabled.
  final bool enableDuplicateFilter;

  /// Offload YUV/NV21 image conversions and ROI cropping to background isolate.
  final bool enableIsolateProcessing;

  /// Analyze frame luminosity and emit low-light alert if below threshold.
  final bool enableAutoBrightnessCheck;

  /// Normalized ambient luminosity threshold (0.0 to 1.0) for low-light detection.
  final double lowLightThreshold;

  /// Automatically trigger digital camera zoom when small barcodes are detected far away.
  final bool enableAutoZoom;

  /// Minimum confidence required to accept a scan result (0.0 to 1.0).
  final double minConfidence;

  /// Constructs a [ScannerOptions] instance.
  const ScannerOptions({
    this.scanStrategy = ScanStrategy.continuous,
    this.scanWindow = ScanWindow.centerReticle,
    this.frameThrottleMs = 100,
    this.duplicateTimeout = const Duration(milliseconds: 1000),
    this.enableDuplicateFilter = true,
    this.enableIsolateProcessing = true,
    this.enableAutoBrightnessCheck = true,
    this.lowLightThreshold = 0.25,
    this.enableAutoZoom = true,
    this.minConfidence = 0.70,
  });

  /// High-performance preset optimized for speed and low CPU consumption.
  static const ScannerOptions highPerformance = ScannerOptions(
    scanStrategy: ScanStrategy.continuous,
    scanWindow: ScanWindow.centerReticle,
    frameThrottleMs: 120,
    duplicateTimeout: Duration(milliseconds: 1200),
    enableDuplicateFilter: true,
    enableIsolateProcessing: true,
    enableAutoBrightnessCheck: true,
    enableAutoZoom: true,
  );

  /// Battery-saver preset for background/inventory batch scanning.
  static const ScannerOptions batterySaver = ScannerOptions(
    scanStrategy: ScanStrategy.batch,
    scanWindow: ScanWindow.centerReticle,
    frameThrottleMs: 200,
    duplicateTimeout: Duration(milliseconds: 1500),
    enableDuplicateFilter: true,
    enableIsolateProcessing: true,
    enableAutoBrightnessCheck: false,
    enableAutoZoom: false,
  );

  ScannerOptions copyWith({
    ScanStrategy? scanStrategy,
    ScanWindow? scanWindow,
    int? frameThrottleMs,
    Duration? duplicateTimeout,
    bool? enableDuplicateFilter,
    bool? enableIsolateProcessing,
    bool? enableAutoBrightnessCheck,
    double? lowLightThreshold,
    bool? enableAutoZoom,
    double? minConfidence,
  }) {
    return ScannerOptions(
      scanStrategy: scanStrategy ?? this.scanStrategy,
      scanWindow: scanWindow ?? this.scanWindow,
      frameThrottleMs: frameThrottleMs ?? this.frameThrottleMs,
      duplicateTimeout: duplicateTimeout ?? this.duplicateTimeout,
      enableDuplicateFilter:
          enableDuplicateFilter ?? this.enableDuplicateFilter,
      enableIsolateProcessing:
          enableIsolateProcessing ?? this.enableIsolateProcessing,
      enableAutoBrightnessCheck:
          enableAutoBrightnessCheck ?? this.enableAutoBrightnessCheck,
      lowLightThreshold: lowLightThreshold ?? this.lowLightThreshold,
      enableAutoZoom: enableAutoZoom ?? this.enableAutoZoom,
      minConfidence: minConfidence ?? this.minConfidence,
    );
  }
}
