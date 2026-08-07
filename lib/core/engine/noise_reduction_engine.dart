import 'dart:math' as math;
import 'dart:typed_data';

/// Image noise reduction and denoising engine implemented in pure Dart.
///
/// Provides multiple denoising strategies inspired by OpenCV and Dynamsoft:
/// - Gaussian blur (configurable kernel size and sigma)
/// - Median filter (salt-and-pepper noise removal)
/// - Bilateral filter approximation (edge-preserving smoothing)
/// - Morphological operations (erosion, dilation, opening, closing)
/// - Adaptive denoising with automatic strength selection based on luminosity
class NoiseReductionEngine {
  /// Applies Gaussian blur with configurable kernel size.
  ///
  /// [gray] — Single-channel grayscale pixel buffer.
  /// [width], [height] — Image dimensions.
  /// [kernelSize] — Must be odd (3, 5, 7). Default: 3.
  /// [sigma] — Gaussian standard deviation. If 0, computed from kernel size.
  ///
  /// Returns the blurred image.
  static Uint8List gaussianBlur(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
    double sigma = 0,
  }) {
    if (gray.length < width * height || width < kernelSize || height < kernelSize) {
      return Uint8List.fromList(gray);
    }

    // Ensure odd kernel size
    final k = kernelSize | 1;
    final half = k ~/ 2;

    // Compute sigma if not specified
    final s = sigma > 0 ? sigma : 0.3 * ((k - 1) * 0.5 - 1) + 0.8;

    // Generate 1D Gaussian kernel (separable for performance)
    final kernel = Float64List(k);
    double kernelSum = 0;
    for (int i = 0; i < k; i++) {
      final x = (i - half).toDouble();
      kernel[i] = math.exp(-(x * x) / (2 * s * s));
      kernelSum += kernel[i];
    }
    // Normalize
    for (int i = 0; i < k; i++) {
      kernel[i] /= kernelSum;
    }

    // Separable convolution: horizontal pass
    final temp = Float64List(width * height);
    for (int y = 0; y < height; y++) {
      final row = y * width;
      for (int x = 0; x < width; x++) {
        double sum = 0;
        for (int kx = -half; kx <= half; kx++) {
          final sx = (x + kx).clamp(0, width - 1);
          sum += gray[row + sx] * kernel[kx + half];
        }
        temp[row + x] = sum;
      }
    }

    // Separable convolution: vertical pass
    final result = Uint8List(width * height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0;
        for (int ky = -half; ky <= half; ky++) {
          final sy = (y + ky).clamp(0, height - 1);
          sum += temp[sy * width + x] * kernel[ky + half];
        }
        result[y * width + x] = sum.round().clamp(0, 255);
      }
    }

    return result;
  }

  /// Applies median filter for salt-and-pepper noise removal.
  ///
  /// Replaces each pixel with the median of its neighborhood.
  /// Very effective for impulse noise while preserving edges.
  ///
  /// [kernelSize] — Must be odd (3, 5, 7). Default: 3.
  ///
  /// Inspired by OpenCV's `cv::medianBlur()`.
  static Uint8List medianFilter(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
  }) {
    if (gray.length < width * height || width < kernelSize || height < kernelSize) {
      return Uint8List.fromList(gray);
    }

    final k = kernelSize | 1;
    final half = k ~/ 2;
    final result = Uint8List(width * height);
    final neighborhood = Int32List(k * k);

    for (int y = half; y < height - half; y++) {
      for (int x = half; x < width - half; x++) {
        int ni = 0;
        for (int ky = -half; ky <= half; ky++) {
          for (int kx = -half; kx <= half; kx++) {
            neighborhood[ni++] = gray[(y + ky) * width + (x + kx)];
          }
        }

        // Sort and take median (using insertion sort for small arrays)
        _insertionSort(neighborhood, ni);
        result[y * width + x] = neighborhood[ni ~/ 2];
      }
    }

    // Copy border pixels
    for (int y = 0; y < half; y++) {
      for (int x = 0; x < width; x++) {
        result[y * width + x] = gray[y * width + x];
        result[(height - 1 - y) * width + x] = gray[(height - 1 - y) * width + x];
      }
    }
    for (int y = half; y < height - half; y++) {
      for (int x = 0; x < half; x++) {
        result[y * width + x] = gray[y * width + x];
        result[y * width + (width - 1 - x)] = gray[y * width + (width - 1 - x)];
      }
    }

    return result;
  }

  /// Applies bilateral filter approximation for edge-preserving smoothing.
  ///
  /// Unlike Gaussian blur, this filter preserves strong edges while smoothing
  /// uniform regions. The filtering considers both spatial distance and
  /// intensity difference between pixels.
  ///
  /// [spatialSigma] — Controls spatial extent of the filter (larger = more blur).
  /// [rangeSigma] — Controls intensity sensitivity (larger = more smoothing across edges).
  /// [kernelSize] — Filter window size (odd, default: 5).
  ///
  /// Inspired by OpenCV's `cv::bilateralFilter()` and Dynamsoft's denoising.
  static Uint8List bilateralFilter(
    Uint8List gray,
    int width,
    int height, {
    double spatialSigma = 2.0,
    double rangeSigma = 25.0,
    int kernelSize = 5,
  }) {
    if (gray.length < width * height || width < kernelSize || height < kernelSize) {
      return Uint8List.fromList(gray);
    }

    final k = kernelSize | 1;
    final half = k ~/ 2;
    final result = Uint8List(width * height);

    // Pre-compute spatial Gaussian weights
    final spatialWeights = Float64List(k * k);
    final twoSpatialSigmaSq = 2.0 * spatialSigma * spatialSigma;
    for (int ky = -half; ky <= half; ky++) {
      for (int kx = -half; kx <= half; kx++) {
        final distSq = (kx * kx + ky * ky).toDouble();
        spatialWeights[(ky + half) * k + (kx + half)] =
            math.exp(-distSq / twoSpatialSigmaSq);
      }
    }

    // Pre-compute range Gaussian LUT (intensity differences 0-255)
    final twoRangeSigmaSq = 2.0 * rangeSigma * rangeSigma;
    final rangeLut = Float64List(256);
    for (int i = 0; i < 256; i++) {
      rangeLut[i] = math.exp(-(i * i).toDouble() / twoRangeSigmaSq);
    }

    for (int y = half; y < height - half; y++) {
      final row = y * width;
      for (int x = half; x < width - half; x++) {
        final centerVal = gray[row + x];
        double weightedSum = 0;
        double weightSum = 0;

        for (int ky = -half; ky <= half; ky++) {
          final ny = y + ky;
          for (int kx = -half; kx <= half; kx++) {
            final nx = x + kx;
            final neighborVal = gray[ny * width + nx];

            final spatialW = spatialWeights[(ky + half) * k + (kx + half)];
            final rangeW = rangeLut[(centerVal - neighborVal).abs()];
            final totalW = spatialW * rangeW;

            weightedSum += neighborVal * totalW;
            weightSum += totalW;
          }
        }

        result[row + x] = weightSum > 0
            ? (weightedSum / weightSum).round().clamp(0, 255)
            : centerVal;
      }
    }

    // Copy border pixels
    for (int y = 0; y < half; y++) {
      for (int x = 0; x < width; x++) {
        result[y * width + x] = gray[y * width + x];
        result[(height - 1 - y) * width + x] = gray[(height - 1 - y) * width + x];
      }
    }
    for (int y = half; y < height - half; y++) {
      for (int x = 0; x < half; x++) {
        result[y * width + x] = gray[y * width + x];
        result[y * width + (width - 1 - x)] = gray[y * width + (width - 1 - x)];
      }
    }

    return result;
  }

  /// Morphological erosion: shrinks bright regions, removes small bright noise.
  ///
  /// [kernelSize] — Structuring element size (odd). Default: 3.
  static Uint8List erode(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
  }) {
    return _morphologyOp(gray, width, height, kernelSize, _MorphOp.erode);
  }

  /// Morphological dilation: expands bright regions, fills small dark gaps.
  ///
  /// [kernelSize] — Structuring element size (odd). Default: 3.
  static Uint8List dilate(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
  }) {
    return _morphologyOp(gray, width, height, kernelSize, _MorphOp.dilate);
  }

  /// Morphological opening: erosion followed by dilation.
  ///
  /// Removes small bright noise while preserving shape and size of larger objects.
  /// Equivalent to OpenCV's `cv::morphologyEx(MORPH_OPEN)`.
  static Uint8List morphOpen(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
  }) {
    final eroded = erode(gray, width, height, kernelSize: kernelSize);
    return dilate(eroded, width, height, kernelSize: kernelSize);
  }

  /// Morphological closing: dilation followed by erosion.
  ///
  /// Fills small dark holes while preserving shape and size of larger objects.
  /// Equivalent to OpenCV's `cv::morphologyEx(MORPH_CLOSE)`.
  static Uint8List morphClose(
    Uint8List gray,
    int width,
    int height, {
    int kernelSize = 3,
  }) {
    final dilated = dilate(gray, width, height, kernelSize: kernelSize);
    return erode(dilated, width, height, kernelSize: kernelSize);
  }

  /// Applies gamma correction for low-light brightness enhancement.
  ///
  /// [gamma] — Gamma value. < 1.0 brightens (e.g., 0.5), > 1.0 darkens.
  /// Typical values: 0.4–0.7 for low-light enhancement.
  ///
  /// Inspired by Apple Vision's auto-exposure compensation.
  static Uint8List gammaCorrection(
    Uint8List gray,
    int width,
    int height, {
    double gamma = 0.6,
  }) {
    if (gray.isEmpty) return gray;

    // Build gamma LUT
    final lut = Uint8List(256);
    final invGamma = 1.0 / gamma;
    for (int i = 0; i < 256; i++) {
      lut[i] = (255.0 * math.pow(i / 255.0, invGamma)).round().clamp(0, 255);
    }

    final result = Uint8List(gray.length);
    for (int i = 0; i < gray.length; i++) {
      result[i] = lut[gray[i]];
    }
    return result;
  }

  /// Applies unsharp mask sharpening.
  ///
  /// Enhances edges by subtracting a blurred version from the original.
  /// Formula: sharpened = original + amount × (original - blurred)
  ///
  /// [amount] — Sharpening strength (0.5–2.0 typical). Default: 1.0.
  /// [blurSigma] — Sigma for the Gaussian blur pass. Default: 1.0.
  static Uint8List unsharpMask(
    Uint8List gray,
    int width,
    int height, {
    double amount = 1.0,
    double blurSigma = 1.0,
  }) {
    final blurred = gaussianBlur(gray, width, height, kernelSize: 5, sigma: blurSigma);
    final result = Uint8List(gray.length);

    for (int i = 0; i < gray.length; i++) {
      final diff = gray[i] - blurred[i];
      final sharpened = gray[i] + (diff * amount).round();
      result[i] = sharpened.clamp(0, 255);
    }

    return result;
  }

  /// Adaptive denoising that automatically selects the best strategy
  /// based on image luminosity and noise level estimation.
  ///
  /// - **Low-light images**: Gamma correction + bilateral filter
  /// - **Normal images**: Light Gaussian blur + unsharp mask
  /// - **High-noise images**: Median filter + morphological opening
  ///
  /// [luminosity] — Normalized average brightness (0.0–1.0).
  /// [noiseEstimate] — Estimated noise level (0.0–1.0). If null, auto-computed.
  ///
  /// Returns the denoised image and the strategy that was applied.
  static DenoiseResult adaptiveDenoise(
    Uint8List gray,
    int width,
    int height, {
    double? luminosity,
    double? noiseEstimate,
  }) {
    // Auto-compute luminosity if not provided
    final luma = luminosity ?? _estimateLuminosity(gray);
    final noise = noiseEstimate ?? _estimateNoise(gray, width, height);

    Uint8List result;
    String strategy;

    if (luma < 0.22) {
      // Low-light: brighten first, then smooth
      final brightened = gammaCorrection(gray, width, height, gamma: 0.55);
      result = bilateralFilter(
        brightened,
        width,
        height,
        spatialSigma: 2.5,
        rangeSigma: 30.0,
      );
      strategy = 'low_light_bilateral';
    } else if (noise > 0.15) {
      // High noise: aggressive denoising
      final median = medianFilter(gray, width, height, kernelSize: 3);
      result = morphOpen(median, width, height, kernelSize: 3);
      strategy = 'high_noise_median_morph';
    } else if (noise > 0.08) {
      // Moderate noise: bilateral filter only
      result = bilateralFilter(
        gray,
        width,
        height,
        spatialSigma: 1.5,
        rangeSigma: 20.0,
      );
      strategy = 'moderate_noise_bilateral';
    } else {
      // Low noise: light Gaussian + sharpening
      final blurred = gaussianBlur(gray, width, height, kernelSize: 3, sigma: 0.8);
      result = unsharpMask(blurred, width, height, amount: 0.5);
      strategy = 'low_noise_sharpen';
    }

    return DenoiseResult(
      bytes: result,
      width: width,
      height: height,
      strategy: strategy,
      estimatedLuminosity: luma,
      estimatedNoise: noise,
    );
  }

  // --- Internal helpers ---

  static Uint8List _morphologyOp(
    Uint8List gray,
    int width,
    int height,
    int kernelSize,
    _MorphOp op,
  ) {
    if (gray.length < width * height) return Uint8List.fromList(gray);

    final k = kernelSize | 1;
    final half = k ~/ 2;
    final result = Uint8List(width * height);

    for (int y = half; y < height - half; y++) {
      for (int x = half; x < width - half; x++) {
        int value = op == _MorphOp.erode ? 255 : 0;

        for (int ky = -half; ky <= half; ky++) {
          for (int kx = -half; kx <= half; kx++) {
            final pixel = gray[(y + ky) * width + (x + kx)];
            if (op == _MorphOp.erode) {
              value = math.min(value, pixel);
            } else {
              value = math.max(value, pixel);
            }
          }
        }

        result[y * width + x] = value;
      }
    }

    // Copy border pixels
    for (int y = 0; y < half; y++) {
      for (int x = 0; x < width; x++) {
        result[y * width + x] = gray[y * width + x];
        result[(height - 1 - y) * width + x] = gray[(height - 1 - y) * width + x];
      }
    }
    for (int y = half; y < height - half; y++) {
      for (int x = 0; x < half; x++) {
        result[y * width + x] = gray[y * width + x];
        result[y * width + (width - 1 - x)] = gray[y * width + (width - 1 - x)];
      }
    }

    return result;
  }

  static void _insertionSort(Int32List arr, int length) {
    for (int i = 1; i < length; i++) {
      final key = arr[i];
      int j = i - 1;
      while (j >= 0 && arr[j] > key) {
        arr[j + 1] = arr[j];
        j--;
      }
      arr[j + 1] = key;
    }
  }

  static double _estimateLuminosity(Uint8List gray) {
    if (gray.isEmpty) return 0.5;
    int sum = 0;
    final step = math.max(1, gray.length ~/ 500);
    int count = 0;
    for (int i = 0; i < gray.length; i += step) {
      sum += gray[i];
      count++;
    }
    return count > 0 ? (sum / count) / 255.0 : 0.5;
  }

  /// Estimates noise level using Median Absolute Deviation (MAD) of Laplacian.
  ///
  /// Based on: σ = 1.4826 × MAD(Laplacian)
  /// This is a robust noise estimator used in image processing research.
  static double _estimateNoise(Uint8List gray, int width, int height) {
    if (gray.length < width * height || width < 3 || height < 3) return 0.0;

    final laplacians = <int>[];
    final step = math.max(2, (width * height) ~/ 2000);

    for (int y = 1; y < height - 1; y += step) {
      final row = y * width;
      for (int x = 1; x < width - 1; x += step) {
        final idx = row + x;
        final lap = (4 * gray[idx] -
                gray[idx - 1] -
                gray[idx + 1] -
                gray[idx - width] -
                gray[idx + width])
            .abs();
        laplacians.add(lap);
      }
    }

    if (laplacians.isEmpty) return 0.0;

    laplacians.sort();
    final median = laplacians[laplacians.length ~/ 2];
    final sigma = 1.4826 * median;

    // Normalize to 0.0–1.0 range (sigma > 30 is considered very noisy)
    return (sigma / 30.0).clamp(0.0, 1.0);
  }
}

enum _MorphOp { erode, dilate }

/// Result of adaptive denoising operation.
class DenoiseResult {
  /// Denoised image bytes.
  final Uint8List bytes;

  /// Image width.
  final int width;

  /// Image height.
  final int height;

  /// Name of the denoising strategy applied.
  final String strategy;

  /// Estimated image luminosity (0.0–1.0).
  final double estimatedLuminosity;

  /// Estimated noise level (0.0–1.0).
  final double estimatedNoise;

  const DenoiseResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.strategy,
    required this.estimatedLuminosity,
    required this.estimatedNoise,
  });
}
