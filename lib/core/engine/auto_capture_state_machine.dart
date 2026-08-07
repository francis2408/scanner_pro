import 'dart:math' as math;
import '../services/document_scanner_service.dart';

/// State of the automatic document capture machine.
enum AutoCaptureState {
  /// Searching for a valid document quadrilateral in frame.
  idle,

  /// Valid quad detected, evaluating stability and sharpness.
  detecting,

  /// Document is held steady; countdown stabilizing for auto capture.
  stabilizing,

  /// Auto capture triggered!
  captured,
}

/// Real-time automatic document capture state machine inspired by Scanbot SDK.
///
/// v3.0 upgrade: Multi-signal fusion scoring combining:
/// - Quad corner drift stability (Euclidean sliding window)
/// - Blur score (Laplacian variance threshold)
/// - Document coverage ratio (quad area / frame area)
/// - Glare detection (hot pixel fraction)
/// - Low-light tolerance with adjusted thresholds
/// - Countdown timer with progress animation support
/// - Quality feedback messages for user guidance
class AutoCaptureStateMachine {
  final int requiredStableFrames;
  final double maxCornerDriftDistance;
  final double minBlurScore;
  final double minCoverageRatio;
  final double maxGlareRatio;

  AutoCaptureState _state = AutoCaptureState.idle;
  final List<DocumentCorners> _quadHistory = [];
  int _consecutiveStableCount = 0;
  double _lastStabilityScore = 0.0;
  double _lastCoverageRatio = 0.0;
  double _lastGlareRatio = 0.0;
  String _qualityFeedback = '';
  DateTime? _stabilizingStartTime;

  AutoCaptureStateMachine({
    this.requiredStableFrames = 5,
    this.maxCornerDriftDistance = 15.0,
    this.minBlurScore = 75.0,
    this.minCoverageRatio = 0.15,
    this.maxGlareRatio = 0.05,
  });

  /// Current state of the auto capture machine.
  AutoCaptureState get state => _state;

  /// Progress fraction towards auto capture (0.0 to 1.0).
  double get progress =>
      (_consecutiveStableCount / requiredStableFrames).clamp(0.0, 1.0);

  /// Recent stability score (1.0 = perfectly steady, 0.0 = moving/unstable).
  double get stabilityScore => _lastStabilityScore;

  /// Current document coverage ratio (quad area / frame area).
  double get coverageRatio => _lastCoverageRatio;

  /// Current glare ratio (hot pixels / total sampled).
  double get glareRatio => _lastGlareRatio;

  /// Human-readable quality feedback message for UI display.
  String get qualityFeedback => _qualityFeedback;

  /// Time when stabilizing phase started (for countdown UI).
  DateTime? get stabilizingStartTime => _stabilizingStartTime;

  /// Consecutive stable frame count.
  int get stableFrameCount => _consecutiveStableCount;

  /// Resets state machine back to idle.
  void reset() {
    _state = AutoCaptureState.idle;
    _quadHistory.clear();
    _consecutiveStableCount = 0;
    _lastStabilityScore = 0.0;
    _lastCoverageRatio = 0.0;
    _lastGlareRatio = 0.0;
    _qualityFeedback = '';
    _stabilizingStartTime = null;
  }

  /// Processes an incoming camera frame with multi-signal fusion.
  ///
  /// Enhanced v3.0: Fuses quad stability, blur, coverage, and glare signals.
  ///
  /// [quad] — Detected document corners (null if no document found).
  /// [blurScore] — Laplacian variance blur score (higher = sharper).
  /// [isLowLight] — Whether the scene is low-light.
  /// [coverageRatio] — Quad area / frame area (0.0–1.0). Optional.
  /// [glareRatio] — Hot pixel fraction (0.0–1.0). Optional.
  ///
  /// Returns `true` if auto capture has just been triggered.
  bool processFrame({
    required DocumentCorners? quad,
    required double blurScore,
    required bool isLowLight,
    double? coverageRatio,
    double? glareRatio,
  }) {
    // Update cached metrics
    _lastCoverageRatio = coverageRatio ?? _lastCoverageRatio;
    _lastGlareRatio = glareRatio ?? _lastGlareRatio;

    // Adjust blur threshold for low-light conditions
    final effectiveMinBlur = isLowLight ? minBlurScore * 0.6 : minBlurScore;

    // Gate 1: Valid quad check
    if (quad == null || !quad.isValidQuad) {
      _resetToIdle('No document detected');
      return false;
    }

    // Gate 2: Blur check
    if (blurScore < effectiveMinBlur) {
      _resetToIdle('Image is blurry — hold steady');
      return false;
    }

    // Gate 3: Coverage check
    if (coverageRatio != null && coverageRatio < minCoverageRatio) {
      _resetToIdle('Move closer to document');
      return false;
    }

    // Gate 4: Glare check
    if (glareRatio != null && glareRatio > maxGlareRatio) {
      _qualityFeedback = 'Glare detected — adjust angle';
      // Don't reset entirely for glare, just pause stabilization
      _consecutiveStableCount = math.max(0, _consecutiveStableCount - 1);
      _state = AutoCaptureState.detecting;
      return false;
    }

    // Add to history
    _quadHistory.add(quad);
    if (_quadHistory.length > requiredStableFrames + 2) {
      _quadHistory.removeAt(0);
    }

    if (_quadHistory.length < 2) {
      _state = AutoCaptureState.detecting;
      _lastStabilityScore = 0.5;
      _qualityFeedback = 'Document detected';
      return false;
    }

    // Compute stability: max corner drift between consecutive frames
    final prev = _quadHistory[_quadHistory.length - 2];
    final curr = quad;

    final d1 = (curr.topLeft - prev.topLeft).distance;
    final d2 = (curr.topRight - prev.topRight).distance;
    final d3 = (curr.bottomRight - prev.bottomRight).distance;
    final d4 = (curr.bottomLeft - prev.bottomLeft).distance;

    final maxDrift = math.max(math.max(d1, d2), math.max(d3, d4));
    _lastStabilityScore =
        (1.0 - (maxDrift / (maxCornerDriftDistance * 2))).clamp(0.0, 1.0);

    // Multi-signal fusion score
    final fusionScore = _computeFusionScore(
      stabilityScore: _lastStabilityScore,
      blurScore: blurScore,
      coverageRatio: _lastCoverageRatio,
      glareRatio: _lastGlareRatio,
    );

    if (maxDrift <= maxCornerDriftDistance && fusionScore > 0.6) {
      _consecutiveStableCount++;

      if (_state != AutoCaptureState.stabilizing) {
        _stabilizingStartTime = DateTime.now();
      }
      _state = AutoCaptureState.stabilizing;
      _qualityFeedback =
          'Hold steady... ${(progress * 100).toInt()}%';

      if (_consecutiveStableCount >= requiredStableFrames) {
        _state = AutoCaptureState.captured;
        _qualityFeedback = 'Captured!';
        return true;
      }
    } else {
      // Gradual decay instead of hard reset (more forgiving)
      _consecutiveStableCount = math.max(0, _consecutiveStableCount - 1);
      _state = AutoCaptureState.detecting;
      _qualityFeedback = maxDrift > maxCornerDriftDistance
          ? 'Hold the device steady'
          : 'Adjusting...';
    }

    return false;
  }

  /// Computes a fused quality score combining multiple signals.
  ///
  /// Each signal is weighted based on its importance:
  /// - Stability: 40% (most important for auto-capture)
  /// - Blur: 30% (critical for image quality)
  /// - Coverage: 20% (ensures document is properly framed)
  /// - Glare: 10% (nice-to-have, not blocking)
  double _computeFusionScore({
    required double stabilityScore,
    required double blurScore,
    required double coverageRatio,
    required double glareRatio,
  }) {
    // Normalize blur score to 0.0–1.0 (assumes blur > 200 is excellent)
    final normalizedBlur = (blurScore / 200.0).clamp(0.0, 1.0);

    // Normalize coverage to 0.0–1.0 (0.5 coverage is ideal)
    final normalizedCoverage =
        (coverageRatio / 0.5).clamp(0.0, 1.0);

    // Invert glare (0 glare = 1.0 score)
    final normalizedGlare = (1.0 - glareRatio * 10).clamp(0.0, 1.0);

    return stabilityScore * 0.4 +
        normalizedBlur * 0.3 +
        normalizedCoverage * 0.2 +
        normalizedGlare * 0.1;
  }

  void _resetToIdle(String feedback) {
    _state = AutoCaptureState.idle;
    _quadHistory.clear();
    _consecutiveStableCount = 0;
    _lastStabilityScore = 0.0;
    _qualityFeedback = feedback;
    _stabilizingStartTime = null;
  }
}
