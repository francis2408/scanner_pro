import 'dart:math' as math;
import 'dart:typed_data';

/// Complete Canny edge detection pipeline implemented in pure Dart.
///
/// Inspired by OpenCV's `cv::Canny()` and Apple Vision's edge detection,
/// this engine performs the full 5-stage Canny algorithm:
/// 1. Gaussian smoothing (5×5 kernel, σ=1.4)
/// 2. Sobel gradient magnitude & direction
/// 3. Non-maximum suppression (edge thinning)
/// 4. Double-threshold hysteresis (strong/weak edge classification)
/// 5. Edge tracking by hysteresis (connectivity-based weak edge promotion)
class CannyEdgeDetector {
  /// Default low threshold ratio relative to high threshold.
  static const double _defaultLowRatio = 0.4;

  /// 5×5 Gaussian kernel (σ ≈ 1.4) pre-computed and flattened.
  /// Sum = 159 for integer approximation.
  static const List<int> _gaussianKernel = [
    2, 4, 5, 4, 2,
    4, 9, 12, 9, 4,
    5, 12, 15, 12, 5,
    4, 9, 12, 9, 4,
    2, 4, 5, 4, 2,
  ];
  static const int _gaussianSum = 159;

  /// Runs the full Canny edge detection pipeline on a grayscale image.
  ///
  /// [gray] — Single-channel grayscale pixel buffer (1 byte per pixel).
  /// [width], [height] — Image dimensions.
  /// [highThreshold] — Upper hysteresis threshold (0–255). Auto-computed via
  ///   Otsu's method if null.
  /// [lowThreshold] — Lower hysteresis threshold. Defaults to
  ///   [highThreshold] × [_defaultLowRatio] if null.
  /// [useAutoThreshold] — When true, computes thresholds automatically from
  ///   the median pixel intensity (recommended for varying lighting).
  ///
  /// Returns a binary edge map (0 or 255 per pixel).
  static Uint8List detect(
    Uint8List gray,
    int width,
    int height, {
    double? highThreshold,
    double? lowThreshold,
    bool useAutoThreshold = true,
  }) {
    if (gray.length < width * height || width < 5 || height < 5) {
      return Uint8List(width * height);
    }

    // Stage 1: Gaussian smoothing to suppress noise
    final smoothed = _applyGaussianBlur(gray, width, height);

    // Stage 2: Sobel gradient magnitude and direction
    final gradientResult = _computeSobelGradient(smoothed, width, height);
    final magnitude = gradientResult.magnitude;
    final direction = gradientResult.direction;

    // Stage 3: Non-maximum suppression (thin edges to 1-pixel width)
    final suppressed = _nonMaxSuppression(
      magnitude,
      direction,
      width,
      height,
    );

    // Compute auto-thresholds if requested
    double high = highThreshold ?? 100.0;
    double low = lowThreshold ?? (high * _defaultLowRatio);

    if (useAutoThreshold && highThreshold == null) {
      final autoThresholds = _computeAutoThresholds(suppressed, width, height);
      high = autoThresholds.high;
      low = autoThresholds.low;
    }

    // Stage 4: Double-threshold classification
    final classified = _doubleThreshold(suppressed, width, height, low, high);

    // Stage 5: Edge tracking by hysteresis
    return _edgeTrackingByHysteresis(classified, width, height);
  }

  /// Applies 5×5 Gaussian blur for noise suppression.
  static Uint8List _applyGaussianBlur(
    Uint8List gray,
    int width,
    int height,
  ) {
    final result = Uint8List(width * height);
    const halfK = 2; // 5×5 kernel → half-size = 2

    for (int y = halfK; y < height - halfK; y++) {
      for (int x = halfK; x < width - halfK; x++) {
        int sum = 0;
        int ki = 0;
        for (int ky = -halfK; ky <= halfK; ky++) {
          final rowIdx = (y + ky) * width;
          for (int kx = -halfK; kx <= halfK; kx++) {
            sum += gray[rowIdx + (x + kx)] * _gaussianKernel[ki];
            ki++;
          }
        }
        result[y * width + x] = (sum ~/ _gaussianSum).clamp(0, 255);
      }
    }

    // Copy border pixels directly (not smoothed)
    for (int y = 0; y < halfK; y++) {
      for (int x = 0; x < width; x++) {
        result[y * width + x] = gray[y * width + x];
        result[(height - 1 - y) * width + x] =
            gray[(height - 1 - y) * width + x];
      }
    }
    for (int y = halfK; y < height - halfK; y++) {
      for (int x = 0; x < halfK; x++) {
        result[y * width + x] = gray[y * width + x];
        result[y * width + (width - 1 - x)] =
            gray[y * width + (width - 1 - x)];
      }
    }

    return result;
  }

  /// Computes Sobel gradient magnitude and quantized direction.
  static _GradientResult _computeSobelGradient(
    Uint8List smoothed,
    int width,
    int height,
  ) {
    final magnitude = Float32List(width * height);
    final direction = Uint8List(width * height); // quantized to 0,1,2,3

    for (int y = 1; y < height - 1; y++) {
      final rowPrev = (y - 1) * width;
      final rowCurr = y * width;
      final rowNext = (y + 1) * width;

      for (int x = 1; x < width - 1; x++) {
        // Sobel X: [-1,0,1; -2,0,2; -1,0,1]
        final gx = -smoothed[rowPrev + x - 1] +
            smoothed[rowPrev + x + 1] -
            2 * smoothed[rowCurr + x - 1] +
            2 * smoothed[rowCurr + x + 1] -
            smoothed[rowNext + x - 1] +
            smoothed[rowNext + x + 1];

        // Sobel Y: [-1,-2,-1; 0,0,0; 1,2,1]
        final gy = -smoothed[rowPrev + x - 1] -
            2 * smoothed[rowPrev + x] -
            smoothed[rowPrev + x + 1] +
            smoothed[rowNext + x - 1] +
            2 * smoothed[rowNext + x] +
            smoothed[rowNext + x + 1];

        final idx = rowCurr + x;
        magnitude[idx] = math.sqrt((gx * gx + gy * gy).toDouble());

        // Quantize direction to 4 angles: 0°, 45°, 90°, 135°
        // Using atan2 and bucketing into nearest 45° increment
        final angle = math.atan2(gy.toDouble(), gx.toDouble());
        final degrees = angle * 180.0 / math.pi;
        final normalized = degrees < 0 ? degrees + 180.0 : degrees;

        if (normalized < 22.5 || normalized >= 157.5) {
          direction[idx] = 0; // 0° — horizontal edge
        } else if (normalized < 67.5) {
          direction[idx] = 1; // 45° — diagonal
        } else if (normalized < 112.5) {
          direction[idx] = 2; // 90° — vertical edge
        } else {
          direction[idx] = 3; // 135° — diagonal
        }
      }
    }

    return _GradientResult(magnitude: magnitude, direction: direction);
  }

  /// Non-maximum suppression: thins edges to single-pixel width.
  ///
  /// For each pixel, checks if its gradient magnitude is the local maximum
  /// along the gradient direction. Suppresses (zeros out) non-maximum pixels.
  static Float32List _nonMaxSuppression(
    Float32List magnitude,
    Uint8List direction,
    int width,
    int height,
  ) {
    final result = Float32List(width * height);

    for (int y = 1; y < height - 1; y++) {
      final row = y * width;
      for (int x = 1; x < width - 1; x++) {
        final idx = row + x;
        final mag = magnitude[idx];

        double neighbor1, neighbor2;

        switch (direction[idx]) {
          case 0: // 0° — compare East/West
            neighbor1 = magnitude[idx + 1];
            neighbor2 = magnitude[idx - 1];
            break;
          case 1: // 45° — compare NE/SW
            neighbor1 = magnitude[idx - width + 1];
            neighbor2 = magnitude[idx + width - 1];
            break;
          case 2: // 90° — compare North/South
            neighbor1 = magnitude[idx - width];
            neighbor2 = magnitude[idx + width];
            break;
          case 3: // 135° — compare NW/SE
            neighbor1 = magnitude[idx - width - 1];
            neighbor2 = magnitude[idx + width + 1];
            break;
          default:
            neighbor1 = 0;
            neighbor2 = 0;
        }

        // Keep pixel only if it's the local maximum along gradient direction
        result[idx] = (mag >= neighbor1 && mag >= neighbor2) ? mag : 0;
      }
    }

    return result;
  }

  /// Double-threshold hysteresis classification.
  ///
  /// Classifies pixels as:
  /// - 255 (strong edge): magnitude ≥ highThreshold
  /// - 128 (weak edge): lowThreshold ≤ magnitude < highThreshold
  /// - 0 (non-edge): magnitude < lowThreshold
  static Uint8List _doubleThreshold(
    Float32List suppressed,
    int width,
    int height,
    double lowThreshold,
    double highThreshold,
  ) {
    final result = Uint8List(width * height);

    for (int i = 0; i < suppressed.length; i++) {
      final val = suppressed[i];
      if (val >= highThreshold) {
        result[i] = 255; // Strong edge
      } else if (val >= lowThreshold) {
        result[i] = 128; // Weak edge (candidate)
      }
      // else: 0 (suppressed / non-edge)
    }

    return result;
  }

  /// Edge tracking by hysteresis: promotes weak edges connected to strong edges.
  ///
  /// A weak edge pixel (128) is promoted to a strong edge (255) if any of its
  /// 8-connected neighbors is a strong edge. Uses iterative propagation until
  /// no more promotions occur.
  static Uint8List _edgeTrackingByHysteresis(
    Uint8List classified,
    int width,
    int height,
  ) {
    final result = Uint8List.fromList(classified);

    // Iterative propagation (converges in 2-4 passes for typical images)
    bool changed = true;
    int maxIterations = 10;

    while (changed && maxIterations-- > 0) {
      changed = false;
      for (int y = 1; y < height - 1; y++) {
        final row = y * width;
        for (int x = 1; x < width - 1; x++) {
          final idx = row + x;
          if (result[idx] != 128) continue; // Only process weak edges

          // Check 8-connected neighborhood for any strong edge
          final hasStrongNeighbor = result[idx - width - 1] == 255 ||
              result[idx - width] == 255 ||
              result[idx - width + 1] == 255 ||
              result[idx - 1] == 255 ||
              result[idx + 1] == 255 ||
              result[idx + width - 1] == 255 ||
              result[idx + width] == 255 ||
              result[idx + width + 1] == 255;

          if (hasStrongNeighbor) {
            result[idx] = 255;
            changed = true;
          }
        }
      }
    }

    // Suppress remaining weak edges (not connected to strong edges)
    for (int i = 0; i < result.length; i++) {
      if (result[i] == 128) {
        result[i] = 0;
      }
    }

    return result;
  }

  /// Computes automatic thresholds based on median pixel intensity.
  ///
  /// Uses the common heuristic: high = median × 1.33, low = median × 0.66.
  /// This adapts well to varying lighting conditions.
  static _ThresholdPair _computeAutoThresholds(
    Float32List magnitude,
    int width,
    int height,
  ) {
    // Build histogram of non-zero magnitudes for median computation
    final histogram = Int32List(256);
    int nonZeroCount = 0;

    for (int i = 0; i < magnitude.length; i++) {
      final val = magnitude[i];
      if (val > 0) {
        histogram[val.toInt().clamp(0, 255)]++;
        nonZeroCount++;
      }
    }

    if (nonZeroCount == 0) {
      return const _ThresholdPair(high: 100.0, low: 40.0);
    }

    // Find median from histogram
    int cumulative = 0;
    final halfCount = nonZeroCount ~/ 2;
    double median = 128.0;

    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative >= halfCount) {
        median = i.toDouble();
        break;
      }
    }

    final high = (median * 1.33).clamp(30.0, 220.0);
    final low = (median * 0.66).clamp(10.0, high * 0.8);

    return _ThresholdPair(high: high, low: low);
  }

  /// Convenience method: detects edges and returns edge pixel count and density.
  static EdgeDetectionResult detectWithStats(
    Uint8List gray,
    int width,
    int height, {
    double? highThreshold,
    double? lowThreshold,
    bool useAutoThreshold = true,
  }) {
    final edges = detect(
      gray,
      width,
      height,
      highThreshold: highThreshold,
      lowThreshold: lowThreshold,
      useAutoThreshold: useAutoThreshold,
    );

    int edgeCount = 0;
    for (int i = 0; i < edges.length; i++) {
      if (edges[i] > 0) edgeCount++;
    }

    final density = edges.isEmpty ? 0.0 : edgeCount / edges.length;

    return EdgeDetectionResult(
      edges: edges,
      width: width,
      height: height,
      edgePixelCount: edgeCount,
      edgeDensity: density,
    );
  }
}

/// Internal gradient computation result.
class _GradientResult {
  final Float32List magnitude;
  final Uint8List direction;

  const _GradientResult({required this.magnitude, required this.direction});
}

/// Internal threshold pair for hysteresis.
class _ThresholdPair {
  final double high;
  final double low;

  const _ThresholdPair({required this.high, required this.low});
}

/// Result of edge detection with statistics.
class EdgeDetectionResult {
  /// Binary edge map (0 or 255 per pixel).
  final Uint8List edges;

  /// Image width.
  final int width;

  /// Image height.
  final int height;

  /// Total number of edge pixels detected.
  final int edgePixelCount;

  /// Edge density (edge pixels / total pixels, range 0.0–1.0).
  final double edgeDensity;

  const EdgeDetectionResult({
    required this.edges,
    required this.width,
    required this.height,
    required this.edgePixelCount,
    required this.edgeDensity,
  });
}
