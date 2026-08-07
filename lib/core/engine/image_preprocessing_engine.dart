import 'dart:math' as math;
import 'dart:typed_data';

import 'noise_reduction_engine.dart';

/// Analysis result from image preprocessing.
class PreprocessingResult {
  /// Grayscale or binarized image bytes.
  final Uint8List bytes;

  /// Width of the processed image.
  final int width;

  /// Height of the processed image.
  final int height;

  /// Laplacian variance blur score (higher = sharper, typically > 100 is sharp).
  final double blurScore;

  /// Whether the image is considered blurry based on threshold.
  final bool isBlurry;

  /// Normalized ambient luminosity (0.0 = total dark, 1.0 = maximum bright).
  final double luminosity;

  /// Contrast RMS score (standard deviation of pixel intensities).
  final double contrastScore;

  /// Whether image suffers from low light / underexposure.
  final bool isLowLight;

  /// Whether image is overexposed / washed out.
  final bool isOverexposed;

  const PreprocessingResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.blurScore,
    required this.isBlurry,
    required this.luminosity,
    required this.contrastScore,
    required this.isLowLight,
    required this.isOverexposed,
  });
}

/// Advanced image preprocessing engine inspired by OpenCV and Dynamsoft algorithms.
/// Includes Sauvola/Niblack adaptive binarization, Laplacian variance blur detection,
/// CLAHE contrast enhancement, and low-light luminance scoring.
class ImagePreprocessingEngine {
  /// Converts RGB or RGBA bytes to a single-channel Grayscale Y-plane.
  static Uint8List toGrayscale(
    Uint8List input,
    int width,
    int height, {
    int bytesPerPixel = 4,
  }) {
    final gray = Uint8List(width * height);
    if (bytesPerPixel == 1 || input.length == width * height) {
      gray.setRange(0, input.length < gray.length ? input.length : gray.length, input);
      return gray;
    }

    for (int i = 0, j = 0; i < input.length && j < gray.length; i += bytesPerPixel, j++) {
      final r = input[i];
      final g = input[i + 1];
      final b = input[i + 2];
      // Standard ITU-R BT.601 luma formula
      gray[j] = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 255);
    }
    return gray;
  }

  /// Calculates Laplacian variance sharpness score for blur detection.
  /// Inspired by OpenCV Laplacian variance algorithm.
  static double computeBlurScore(Uint8List gray, int width, int height) {
    if (gray.length < width * height || width < 3 || height < 3) return 0.0;

    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    // 3x3 Discrete Laplacian Kernel:
    // [  0,  1,  0 ]
    // [  1, -4,  1 ]
    // [  0,  1,  0 ]
    final stride = width;
    for (int y = 1; y < height - 1; y += 2) {
      final row = y * stride;
      for (int x = 1; x < width - 1; x += 2) {
        final idx = row + x;
        final lap = gray[idx - stride] +
            gray[idx - 1] +
            gray[idx + 1] +
            gray[idx + stride] -
            (4 * gray[idx]);
        final val = lap.toDouble();
        sum += val;
        sumSq += val * val;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return math.max(0.0, variance);
  }

  /// Computes average normalized luminosity and RMS contrast score.
  static Map<String, double> computeLuminosityAndContrast(
    Uint8List gray,
    int width,
    int height,
  ) {
    if (gray.isEmpty) {
      return {'luminosity': 0.5, 'contrast': 0.0};
    }

    int sum = 0;
    int step = (gray.length ~/ 1000).clamp(1, 100);
    int count = 0;
    for (int i = 0; i < gray.length; i += step) {
      sum += gray[i];
      count++;
    }

    final avgLuma = count > 0 ? (sum / count) / 255.0 : 0.5;

    // Calculate RMS contrast (standard deviation)
    double varSum = 0.0;
    final meanVal = avgLuma * 255.0;
    for (int i = 0; i < gray.length; i += step) {
      final diff = gray[i] - meanVal;
      varSum += diff * diff;
    }
    final contrast = count > 0 ? math.sqrt(varSum / count) / 128.0 : 0.0;

    return {'luminosity': avgLuma, 'contrast': contrast};
  }

  /// Sauvola's Local Adaptive Binarization algorithm for document OCR & barcode decoding.
  /// Formula: T(x,y) = m(x,y) * [1 + k * (s(x,y)/R - 1)]
  /// where m = local mean, s = local std dev, k = 0.2, R = 128.
  static Uint8List sauvolaBinarize(
    Uint8List gray,
    int width,
    int height, {
    int windowSize = 15,
    double k = 0.2,
    double r = 128.0,
  }) {
    final binarized = Uint8List(width * height);
    final halfWindow = windowSize ~/ 2;

    // Build Integral Image and Integral Squared Image for fast local box sums
    final intW = width + 1;
    final intH = height + 1;
    final integral = Float64List(intW * intH);
    final integralSq = Float64List(intW * intH);

    for (int y = 0; y < height; y++) {
      double rowSum = 0.0;
      double rowSumSq = 0.0;
      for (int x = 0; x < width; x++) {
        final val = gray[y * width + x].toDouble();
        rowSum += val;
        rowSumSq += val * val;

        final idx = (y + 1) * intW + (x + 1);
        final topIdx = y * intW + (x + 1);
        integral[idx] = integral[topIdx] + rowSum;
        integralSq[idx] = integralSq[topIdx] + rowSumSq;
      }
    }

    for (int y = 0; y < height; y++) {
      final y0 = math.max(0, y - halfWindow);
      final y1 = math.min(height - 1, y + halfWindow);

      for (int x = 0; x < width; x++) {
        final x0 = math.max(0, x - halfWindow);
        final x1 = math.min(width - 1, x + halfWindow);

        final area = (x1 - x0 + 1) * (y1 - y0 + 1);

        // Box query on integral images
        final i00 = y0 * intW + x0;
        final i01 = y0 * intW + (x1 + 1);
        final i10 = (y1 + 1) * intW + x0;
        final i11 = (y1 + 1) * intW + (x1 + 1);

        final sum = integral[i11] - integral[i01] - integral[i10] + integral[i00];
        final sumSq = integralSq[i11] - integralSq[i01] - integralSq[i10] + integralSq[i00];

        final mean = sum / area;
        final variance = math.max(0.0, (sumSq / area) - (mean * mean));
        final stdDev = math.sqrt(variance);

        final threshold = mean * (1.0 + k * ((stdDev / r) - 1.0));
        final pixel = gray[y * width + x];

        binarized[y * width + x] = pixel >= threshold ? 255 : 0;
      }
    }

    return binarized;
  }

  /// Otsu's Global Adaptive Thresholding algorithm.
  static Uint8List otsuBinarize(Uint8List gray, int width, int height) {
    final histogram = Int32List(256);
    final total = gray.length;

    for (int i = 0; i < total; i++) {
      histogram[gray[i]]++;
    }

    double sum = 0.0;
    for (int t = 0; t < 256; t++) {
      sum += t * histogram[t];
    }

    double sumB = 0.0;
    int wB = 0;
    double maxVar = 0.0;
    int threshold = 128;

    for (int t = 0; t < 256; t++) {
      wB += histogram[t];
      if (wB == 0) continue;

      final wF = total - wB;
      if (wF == 0) break;

      sumB += t * histogram[t];
      final mB = sumB / wB;
      final mF = (sum - sumB) / wF;

      final varBetween = wB.toDouble() * wF.toDouble() * (mB - mF) * (mB - mF);

      if (varBetween > maxVar) {
        maxVar = varBetween;
        threshold = t;
      }
    }

    final out = Uint8List(total);
    for (int i = 0; i < total; i++) {
      out[i] = gray[i] >= threshold ? 255 : 0;
    }
    return out;
  }

  /// Contrast Limited Adaptive Histogram Equalization (CLAHE) approximation.
  static Uint8List enhanceContrast(Uint8List gray, int width, int height) {
    final out = Uint8List(gray.length);
    final histogram = Int32List(256);

    for (int i = 0; i < gray.length; i++) {
      histogram[gray[i]]++;
    }

    // Cumulative distribution function (CDF)
    final cdf = Float32List(256);
    cdf[0] = histogram[0].toDouble();
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + histogram[i];
    }

    final cdfMin = cdf.firstWhere((val) => val > 0, orElse: () => 1.0);
    final totalPixels = gray.length.toDouble();

    for (int i = 0; i < gray.length; i++) {
      final val = gray[i];
      final equalized = ((cdf[val] - cdfMin) / (totalPixels - cdfMin) * 255.0).clamp(0.0, 255.0);
      out[i] = equalized.toInt();
    }
    return out;
  }

  /// Preprocesses a raw image frame and returns a comprehensive [PreprocessingResult].
  static PreprocessingResult processFrame(
    Uint8List rawBytes,
    int width,
    int height, {
    double blurThreshold = 80.0,
    bool applyBinarization = false,
  }) {
    final gray = toGrayscale(rawBytes, width, height);
    final blurScore = computeBlurScore(gray, width, height);
    final lumaData = computeLuminosityAndContrast(gray, width, height);

    final luma = lumaData['luminosity'] ?? 0.5;
    final contrast = lumaData['contrast'] ?? 0.5;

    final isBlurry = blurScore < blurThreshold;
    final isLowLight = luma < 0.22;
    final isOverexposed = luma > 0.88;

    Uint8List finalBytes = gray;
    if (applyBinarization) {
      finalBytes = sauvolaBinarize(gray, width, height);
    }

    return PreprocessingResult(
      bytes: finalBytes,
      width: width,
      height: height,
      blurScore: blurScore,
      isBlurry: isBlurry,
      luminosity: luma,
      contrastScore: contrast,
      isLowLight: isLowLight,
      isOverexposed: isOverexposed,
    );
  }

  /// Applies Gamma Correction for low-light brightness enhancement.
  ///
  /// Inspired by Apple Vision's auto-exposure compensation.
  /// [gamma] < 1.0 brightens the image (e.g., 0.5 for dark scenes).
  /// [gamma] > 1.0 darkens the image.
  static Uint8List gammaCorrection(
    Uint8List gray,
    int width,
    int height, {
    double gamma = 0.6,
  }) {
    return NoiseReductionEngine.gammaCorrection(
      gray,
      width,
      height,
      gamma: gamma,
    );
  }

  /// Applies histogram auto-levels using percentile-based stretching.
  ///
  /// Maps the [lowPercentile]–[highPercentile] intensity range to 0–255,
  /// clipping outliers. More robust than simple min-max contrast stretch.
  ///
  /// Inspired by Scanbot SDK's auto-enhancement algorithm.
  static Uint8List histogramAutoLevels(
    Uint8List gray,
    int width,
    int height, {
    double lowPercentile = 0.01,
    double highPercentile = 0.99,
  }) {
    if (gray.isEmpty) return gray;

    // Build histogram
    final histogram = Int32List(256);
    for (int i = 0; i < gray.length; i++) {
      histogram[gray[i]]++;
    }

    // Find percentile bounds
    final total = gray.length;
    final lowCount = (total * lowPercentile).round();
    final highCount = (total * highPercentile).round();

    int low = 0, high = 255;
    int cumulative = 0;
    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative >= lowCount && low == 0) low = i;
      if (cumulative >= highCount) {
        high = i;
        break;
      }
    }

    if (high <= low) return gray;

    // Apply linear stretch
    final result = Uint8List(gray.length);
    final scale = 255.0 / (high - low);
    for (int i = 0; i < gray.length; i++) {
      result[i] = ((gray[i] - low) * scale).clamp(0, 255).toInt();
    }

    return result;
  }

  /// Applies Unsharp Mask sharpening.
  ///
  /// Enhances edges by: sharpened = original + amount × (original - blurred)
  ///
  /// [amount] — Sharpening strength (0.5–2.0 typical).
  /// [blurSigma] — Sigma for the Gaussian blur pass.
  static Uint8List unsharpMask(
    Uint8List gray,
    int width,
    int height, {
    double amount = 1.0,
    double blurSigma = 1.0,
  }) {
    return NoiseReductionEngine.unsharpMask(
      gray,
      width,
      height,
      amount: amount,
      blurSigma: blurSigma,
    );
  }

  /// Edge-preserving bilateral filter.
  ///
  /// Smooths uniform regions while preserving strong edges.
  /// Uses both spatial distance and intensity difference as filter weights.
  static Uint8List bilateralFilter(
    Uint8List gray,
    int width,
    int height, {
    double spatialSigma = 2.0,
    double rangeSigma = 25.0,
    int kernelSize = 5,
  }) {
    return NoiseReductionEngine.bilateralFilter(
      gray,
      width,
      height,
      spatialSigma: spatialSigma,
      rangeSigma: rangeSigma,
      kernelSize: kernelSize,
    );
  }

  /// Computes Tenengrad sharpness score using Sobel gradient sum.
  ///
  /// More robust than Laplacian variance for document scanning.
  /// Returns higher values for sharper images.
  static double computeTenengradScore(Uint8List gray, int width, int height) {
    if (gray.length < width * height || width < 3 || height < 3) return 0.0;

    double sumGradientSq = 0.0;
    int count = 0;
    final step = math.max(2, (width * height) ~/ 5000);

    for (int y = 1; y < height - 1; y += step) {
      final row = y * width;
      for (int x = 1; x < width - 1; x += step) {
        final idx = row + x;

        // Sobel X: horizontal gradient
        final gx = gray[idx + 1] - gray[idx - 1];
        // Sobel Y: vertical gradient
        final gy = gray[idx + width] - gray[idx - width];

        sumGradientSq += gx * gx + gy * gy;
        count++;
      }
    }

    return count > 0 ? sumGradientSq / count : 0.0;
  }

  /// Multi-pass adaptive preprocessing pipeline.
  ///
  /// Analyzes the input image conditions and applies the optimal
  /// preprocessing chain for the given scan mode context.
  ///
  /// Pass 1: Quality assessment (blur, luminosity, contrast)
  /// Pass 2: Condition-based enhancement (gamma, CLAHE, bilateral)
  /// Pass 3: Mode-specific final prep (binarization, sharpening)
  ///
  /// [context] — Describes the scan mode and desired preprocessing behavior.
  ///
  /// Returns an [AdaptivePreprocessResult] with the best-processed output.
  static AdaptivePreprocessResult multiPassAdaptivePreprocess(
    Uint8List rawBytes,
    int width,
    int height, {
    bool isLowLight = false,
    bool requiresBinarization = false,
    bool requiresSharpening = false,
    double blurThreshold = 80.0,
  }) {
    final steps = <String>[];

    // Pass 1: Convert to grayscale and assess quality
    Uint8List gray = toGrayscale(rawBytes, width, height);
    final blurScore = computeBlurScore(gray, width, height);
    final lumaData = computeLuminosityAndContrast(gray, width, height);
    final luma = lumaData['luminosity'] ?? 0.5;
    final contrast = lumaData['contrast'] ?? 0.5;

    final detectedLowLight = isLowLight || luma < 0.22;
    final lowContrast = contrast < 0.3;

    // Pass 2: Condition-based enhancement
    if (detectedLowLight) {
      // Brighten via gamma correction
      gray = gammaCorrection(gray, width, height, gamma: 0.55);
      steps.add('gamma_correction(0.55)');

      // Denoise (low-light images are noisier)
      gray = NoiseReductionEngine.bilateralFilter(
        gray,
        width,
        height,
        spatialSigma: 2.0,
        rangeSigma: 25.0,
      );
      steps.add('bilateral_denoise');
    }

    if (lowContrast) {
      // Boost contrast with histogram auto-levels
      gray = histogramAutoLevels(gray, width, height);
      steps.add('histogram_auto_levels');
    } else if (contrast > 0.3 && contrast < 0.7) {
      // Moderate contrast: apply CLAHE
      gray = enhanceContrast(gray, width, height);
      steps.add('clahe_enhancement');
    }

    // Pass 3: Mode-specific final prep
    if (requiresSharpening && blurScore < blurThreshold * 1.5) {
      gray = unsharpMask(gray, width, height, amount: 0.8, blurSigma: 1.0);
      steps.add('unsharp_mask(0.8)');
    }

    Uint8List finalBytes = gray;
    if (requiresBinarization) {
      // Use Sauvola for OCR/document, Otsu for barcodes
      finalBytes = sauvolaBinarize(gray, width, height);
      steps.add('sauvola_binarization');
    }

    // Recompute quality metrics after enhancement
    final finalBlur = computeBlurScore(finalBytes, width, height);
    final finalLuma = computeLuminosityAndContrast(finalBytes, width, height);

    return AdaptivePreprocessResult(
      bytes: finalBytes,
      width: width,
      height: height,
      stepsApplied: steps,
      originalBlurScore: blurScore,
      enhancedBlurScore: finalBlur,
      originalLuminosity: luma,
      enhancedLuminosity: finalLuma['luminosity'] ?? luma,
      originalContrast: contrast,
      enhancedContrast: finalLuma['contrast'] ?? contrast,
    );
  }
}

/// Result of multi-pass adaptive preprocessing.
class AdaptivePreprocessResult {
  /// Processed grayscale image bytes.
  final Uint8List bytes;

  /// Image width.
  final int width;

  /// Image height.
  final int height;

  /// Ordered list of preprocessing steps applied.
  final List<String> stepsApplied;

  /// Blur score before enhancement.
  final double originalBlurScore;

  /// Blur score after enhancement.
  final double enhancedBlurScore;

  /// Luminosity before enhancement.
  final double originalLuminosity;

  /// Luminosity after enhancement.
  final double enhancedLuminosity;

  /// Contrast before enhancement.
  final double originalContrast;

  /// Contrast after enhancement.
  final double enhancedContrast;

  const AdaptivePreprocessResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.stepsApplied,
    required this.originalBlurScore,
    required this.enhancedBlurScore,
    required this.originalLuminosity,
    required this.enhancedLuminosity,
    required this.originalContrast,
    required this.enhancedContrast,
  });
}
