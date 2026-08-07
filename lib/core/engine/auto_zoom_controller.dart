import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Smooth camera auto-zoom controller inspired by Dynamsoft Barcode Reader SDK.
///
/// v3.0 upgrade: Replaces instant zoom jumps with smooth animated zoom using
/// ease-out interpolation, settling detection, velocity limiting, and
/// hysteresis band to prevent zoom oscillation.
///
/// Features:
/// - Smooth ease-out zoom animation (configurable duration)
/// - Zoom settling detection (N stable frames before declaring complete)
/// - Maximum zoom velocity limiting (prevents jarring jumps)
/// - Hysteresis band (±5% dead zone to prevent oscillation)
/// - Distance estimation from barcode module size
class AutoZoomController {
  final double minZoom;
  final double maxZoom;
  final double targetAreaFraction;
  final double lerpFactor;

  /// Maximum zoom change per update (velocity limiter).
  final double maxZoomVelocity;

  /// Hysteresis band: don't adjust zoom for area changes within this range.
  final double hysteresisBand;

  /// Number of stable frames required before zoom is considered settled.
  final int settlingFrameCount;

  double _currentZoom = 1.0;
  double _targetZoom = 1.0;
  DateTime? _lastZoomChangeTime;
  int _stableFrameCount = 0;
  bool _isSettled = false;
  double _lastAreaRatio = 0.0;

  AutoZoomController({
    this.minZoom = 1.0,
    this.maxZoom = 5.0,
    this.targetAreaFraction = 0.25,
    this.lerpFactor = 0.15,
    this.maxZoomVelocity = 0.4,
    this.hysteresisBand = 0.05,
    this.settlingFrameCount = 5,
  });

  /// Current zoom factor level.
  double get currentZoom => _currentZoom;

  /// Target zoom level being animated towards.
  double get targetZoom => _targetZoom;

  /// Whether zoom has settled (stable for N frames).
  bool get isSettled => _isSettled;

  /// Number of consecutive stable frames.
  int get stableFrames => _stableFrameCount;

  /// Time when zoom level was last adjusted.
  DateTime? get lastZoomChangeTime => _lastZoomChangeTime;

  /// Resets zoom back to minimum 1.0.
  void reset() {
    _currentZoom = minZoom;
    _targetZoom = minZoom;
    _lastZoomChangeTime = null;
    _stableFrameCount = 0;
    _isSettled = false;
    _lastAreaRatio = 0.0;
  }

  /// Calculates desired target zoom level based on target bounding box area
  /// relative to scan window ROI.
  ///
  /// Enhanced v3.0: Uses smooth interpolation with velocity limiting and
  /// hysteresis band to prevent zoom oscillation.
  double evaluateTargetZoom({
    required Rect targetBoundingBox,
    required Rect roiScanWindow,
    required Size frameSize,
  }) {
    if (targetBoundingBox.isEmpty ||
        roiScanWindow.isEmpty ||
        roiScanWindow.width <= 0) {
      // No target detected — slowly zoom back towards minimum
      if (_currentZoom > minZoom + 0.1) {
        _targetZoom = math.max(minZoom, _currentZoom - 0.05);
        _currentZoom = _smoothStep(_currentZoom, _targetZoom, lerpFactor);
        _lastZoomChangeTime = DateTime.now();
        _stableFrameCount = 0;
        _isSettled = false;
      }
      return _currentZoom;
    }

    final targetArea = targetBoundingBox.width * targetBoundingBox.height;
    final roiArea = roiScanWindow.width * roiScanWindow.height;

    if (roiArea <= 0 || targetArea <= 0) return _currentZoom;

    final currentRatio = targetArea / roiArea;

    // Hysteresis: ignore small area changes within the dead zone
    if ((_lastAreaRatio - currentRatio).abs() < hysteresisBand &&
        _stableFrameCount > 0) {
      _stableFrameCount++;
      if (_stableFrameCount >= settlingFrameCount) {
        _isSettled = true;
      }
      return _currentZoom;
    }

    _lastAreaRatio = currentRatio;

    // Calculate desired zoom based on area ratio
    if (currentRatio < targetAreaFraction) {
      // Target is too small — zoom in
      final neededScale =
          math.sqrt(targetAreaFraction / math.max(0.01, currentRatio));
      _targetZoom = (_currentZoom * neededScale).clamp(minZoom, maxZoom);
    } else if (currentRatio > 0.6 && _currentZoom > minZoom) {
      // Target fills > 60% of ROI — zoom out
      _targetZoom = math.max(minZoom, _currentZoom / 1.15);
    } else {
      // Target is well-framed — maintain current zoom
      _stableFrameCount++;
      if (_stableFrameCount >= settlingFrameCount) {
        _isSettled = true;
      }
      return _currentZoom;
    }

    // Apply velocity limiting
    final delta = _targetZoom - _currentZoom;
    final clampedDelta = delta.clamp(-maxZoomVelocity, maxZoomVelocity);
    final velocityLimitedTarget = _currentZoom + clampedDelta;

    // Smooth ease-out interpolation towards target
    _currentZoom = _smoothStep(
      _currentZoom,
      velocityLimitedTarget,
      lerpFactor,
    );

    _lastZoomChangeTime = DateTime.now();
    _stableFrameCount = 0;
    _isSettled = false;

    return _currentZoom;
  }

  /// Estimates optimal zoom level from barcode module size.
  ///
  /// Uses the narrowest bar/module width to estimate distance and
  /// calculate the zoom needed for reliable decoding.
  ///
  /// [moduleWidthPixels] — Width of the narrowest barcode module in pixels.
  /// [idealModuleWidth] — Target module width for reliable decoding (default: 3.0px).
  double estimateZoomFromModuleSize({
    required double moduleWidthPixels,
    double idealModuleWidth = 3.0,
  }) {
    if (moduleWidthPixels <= 0) return _currentZoom;

    final neededScale = idealModuleWidth / moduleWidthPixels;
    if (neededScale <= 1.0) return _currentZoom; // Already large enough

    _targetZoom = (_currentZoom * neededScale).clamp(minZoom, maxZoom);
    return _targetZoom;
  }

  /// Smooth step interpolation with ease-out curve.
  ///
  /// Produces smooth, decelerating zoom transitions that feel natural.
  static double _smoothStep(double current, double target, double factor) {
    final diff = target - current;
    // Ease-out: faster at start, slower near target
    final eased = diff * factor * (2.0 - factor);
    return current + eased;
  }
}

