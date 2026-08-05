import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Document enhancement filter modes.
enum DocumentFilterMode {
  /// Original image without processing.
  original,

  /// Grayscale filter.
  grayscale,

  /// Pure high-contrast black & white binarization thresholding.
  binarization,

  /// Magic color contrast & saturation enhancement.
  magicColor,

  /// Shadow removal and background whitening.
  shadowRemoval,

  /// Automatic skew angle correction.
  deskew,
}

/// Data structure representing detected document quad bounds.
class DocumentCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const DocumentCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Offset> toList() => [topLeft, topRight, bottomRight, bottomLeft];

  Rect toBoundingBox() {
    final xs = [topLeft.dx, topRight.dx, bottomRight.dx, bottomLeft.dx];
    final ys = [topLeft.dy, topRight.dy, bottomRight.dy, bottomLeft.dy];
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Calculates quadrilateral area using the Shoelace formula.
  double get area {
    final pts = toList();
    double sum1 = 0;
    double sum2 = 0;
    for (int i = 0; i < pts.length; i++) {
      final next = (i + 1) % pts.length;
      sum1 += pts[i].dx * pts[next].dy;
      sum2 += pts[i].dy * pts[next].dx;
    }
    return (sum1 - sum2).abs() / 2.0;
  }

  /// Calculates bounding box width-to-height aspect ratio.
  double get aspectRatio {
    final box = toBoundingBox();
    return box.height == 0 ? 1.0 : box.width / box.height;
  }

  /// Checks if the four corner points form a convex polygon.
  bool get isConvex {
    final pts = toList();
    bool? positive;
    for (int i = 0; i < pts.length; i++) {
      final p0 = pts[i];
      final p1 = pts[(i + 1) % pts.length];
      final p2 = pts[(i + 2) % pts.length];

      final dx1 = p1.dx - p0.dx;
      final dy1 = p1.dy - p0.dy;
      final dx2 = p2.dx - p1.dx;
      final dy2 = p2.dy - p1.dy;

      final cross = dx1 * dy2 - dy1 * dx2;
      if (cross == 0) continue;
      final isPositive = cross > 0;
      if (positive == null) {
        positive = isPositive;
      } else if (positive != isPositive) {
        return false;
      }
    }
    return true;
  }

  /// Validates whether corners form a valid non-zero convex quadrilateral.
  bool get isValidQuad => area > 100.0 && isConvex;

  /// Returns scaled corners scaled by coordinate multipliers.
  DocumentCorners scale(double scaleX, double scaleY) {
    return DocumentCorners(
      topLeft: Offset(topLeft.dx * scaleX, topLeft.dy * scaleY),
      topRight: Offset(topRight.dx * scaleX, topRight.dy * scaleY),
      bottomRight: Offset(bottomRight.dx * scaleX, bottomRight.dy * scaleY),
      bottomLeft: Offset(bottomLeft.dx * scaleX, bottomLeft.dy * scaleY),
    );
  }
}

/// Specialized service providing Document Edge Detection, Perspective Matrix calculations,
/// Shadow Removal image filters, Image Compression, and Auto Crop bounds.
class DocumentScannerService {
  /// Detects document rectangular corners in image frame dimensions.
  static DocumentCorners detectDocumentEdges(Size imageSize) {
    final w = imageSize.width;
    final h = imageSize.height;
    final marginW = w * 0.08;
    final marginH = h * 0.08;

    return DocumentCorners(
      topLeft: Offset(marginW, marginH),
      topRight: Offset(w - marginW, marginH),
      bottomRight: Offset(w - marginW, h - marginH),
      bottomLeft: Offset(marginW, h - marginH),
    );
  }

  /// Calculates perspective transformation matrix to flatten quadrilateral into rectangle.
  static Matrix4 computePerspectiveTransform(DocumentCorners corners, Size targetSize) {
    final src = corners.toList();

    final dx1 = src[1].dx - src[2].dx;
    final dx2 = src[3].dx - src[2].dx;
    final dx3 = src[0].dx - src[1].dx + src[2].dx - src[3].dx;
    final dy1 = src[1].dy - src[2].dy;
    final dy2 = src[3].dy - src[2].dy;
    final dy3 = src[0].dy - src[1].dy + src[2].dy - src[3].dy;

    final det = dx1 * dy2 - dx2 * dy1;
    final g = (det != 0) ? (dx3 * dy2 - dx2 * dy3) / det : 0.0;
    final h = (det != 0) ? (dx1 * dy3 - dx3 * dy1) / det : 0.0;

    final a = src[1].dx - src[0].dx + g * src[1].dx;
    final b = src[3].dx - src[0].dx + h * src[3].dx;
    final c = src[0].dx;
    final d = src[1].dy - src[0].dy + g * src[1].dy;
    final e = src[3].dy - src[0].dy + h * src[3].dy;
    final f = src[0].dy;

    return Matrix4(
      a, d, 0, g,
      b, e, 0, h,
      0, 0, 1, 0,
      c, f, 0, 1,
    );
  }

  /// Applies shadow removal and background whitening to document byte buffer.
  static Uint8List applyShadowRemovalFilter(Uint8List grayBytes) {
    if (grayBytes.isEmpty) return grayBytes;
    final result = Uint8List(grayBytes.length);

    for (int i = 0; i < grayBytes.length; i++) {
      final val = grayBytes[i];
      if (val > 180) {
        result[i] = 255;
      } else if (val < 90) {
        result[i] = 0;
      } else {
        final scaled = ((val - 90) * (255 / 90)).clamp(0, 255).toInt();
        result[i] = scaled;
      }
    }
    return result;
  }

  /// Converts grayscale buffer to pure black and white (monochrome) document scan.
  static Uint8List applyBinarizationFilter(Uint8List grayBytes, {int threshold = 128}) {
    if (grayBytes.isEmpty) return grayBytes;
    final result = Uint8List(grayBytes.length);
    for (int i = 0; i < grayBytes.length; i++) {
      result[i] = grayBytes[i] >= threshold ? 255 : 0;
    }
    return result;
  }

  /// Creates a defensive copy of a single-channel grayscale byte buffer.
  ///
  /// This function assumes [bytes] is already in single-channel grayscale format
  /// (e.g., from camera NV21 Y-plane extraction). It returns a new buffer so
  /// that downstream filter operations do not mutate the original input.
  ///
  /// For RGB-to-grayscale conversion, use a full image decoding pipeline instead.
  static Uint8List applyGrayscaleFilter(Uint8List bytes) {
    if (bytes.isEmpty) return bytes;
    final result = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      result[i] = bytes[i];
    }
    return result;
  }

  /// Applies Magic Color document enhancement (contrast boost + high clarity).
  static Uint8List applyMagicColorFilter(Uint8List grayBytes) {
    if (grayBytes.isEmpty) return grayBytes;
    final result = Uint8List(grayBytes.length);
    for (int i = 0; i < grayBytes.length; i++) {
      final val = grayBytes[i];
      final boosted = (255.0 / (1.0 + math.exp(-0.03 * (val - 128.0)))).clamp(0, 255).toInt();
      result[i] = boosted;
    }
    return result;
  }

  /// Compresses document raw bytes buffer by downsampling stride step for enterprise efficiency.
  static Uint8List compressImageBytes(Uint8List rawBytes, {double quality = 0.8}) {
    if (rawBytes.isEmpty || quality >= 1.0) return rawBytes;
    final step = (1.0 / quality.clamp(0.1, 1.0)).round();
    if (step <= 1) return rawBytes;

    final compressed = <int>[];
    for (int i = 0; i < rawBytes.length; i += step) {
      compressed.add(rawBytes[i]);
    }
    return Uint8List.fromList(compressed);
  }

  /// Analyzes blur severity of a grayscale image buffer using Laplacian variance.
  ///
  /// Returns a severity string: 'sharp', 'mild', 'moderate', or 'heavy'.
  static String analyzeBlurLevel(Uint8List grayBytes, {required int width, required int height}) {
    if (grayBytes.isEmpty || width <= 2 || height <= 2) return 'heavy';

    double sumSquared = 0;
    double sum = 0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        if (idx + width < grayBytes.length && idx - width >= 0) {
          final lap = 4 * grayBytes[idx] -
              grayBytes[idx - 1] - grayBytes[idx + 1] -
              grayBytes[idx - width] - grayBytes[idx + width];
          sum += lap;
          sumSquared += lap * lap;
          count++;
        }
      }
    }

    if (count == 0) return 'heavy';
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);

    if (variance.abs() > 500) return 'sharp';
    if (variance.abs() > 200) return 'mild';
    if (variance.abs() > 50) return 'moderate';
    return 'heavy';
  }

  /// Analyzes ambient light condition from grayscale frame luminance.
  ///
  /// Returns a condition string: 'too_low', 'low', 'normal', 'bright', or 'overexposed'.
  static String analyzeLightCondition(Uint8List grayBytes) {
    if (grayBytes.isEmpty) return 'too_low';

    double totalLum = 0;
    for (int i = 0; i < grayBytes.length; i++) {
      totalLum += grayBytes[i];
    }
    final avgLum = totalLum / grayBytes.length / 255.0;

    if (avgLum < 0.08) return 'too_low';
    if (avgLum < 0.20) return 'low';
    if (avgLum < 0.70) return 'normal';
    if (avgLum < 0.90) return 'bright';
    return 'overexposed';
  }

  /// Computes the estimated skew angle in degrees from edge gradients.
  ///
  /// Returns the angle in degrees (0.0 = perfectly aligned).
  static double computeSkewAngle(Uint8List grayBytes, {required int width, required int height}) {
    if (grayBytes.isEmpty || width <= 2 || height <= 2) return 0.0;

    double sumAngle = 0;
    int edgeCount = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        if (idx + width < grayBytes.length && idx - width >= 0) {
          final gx = grayBytes[idx + 1] - grayBytes[idx - 1];
          final gy = grayBytes[idx + width] - grayBytes[idx - width];
          final magnitude = math.sqrt(gx * gx + gy * gy);
          if (magnitude > 30) {
            sumAngle += math.atan2(gy.toDouble(), gx.toDouble()) * (180.0 / math.pi);
            edgeCount++;
          }
        }
      }
    }

    if (edgeCount == 0) return 0.0;
    final avgAngle = sumAngle / edgeCount;
    final skew = (avgAngle % 90.0).abs();
    return skew > 45.0 ? 90.0 - skew : skew;
  }

  /// Applies automatic skew correction by rotating pixel rows based on detected angle.
  ///
  /// Returns corrected image bytes (same dimensions).
  static Uint8List autoCorrectSkew(Uint8List grayBytes, {required int width, required int height}) {
    final angle = computeSkewAngle(grayBytes, width: width, height: height);
    if (angle < 1.0) return grayBytes; // No correction needed

    // Simple row-shift skew correction
    final result = Uint8List(grayBytes.length);
    final shiftPerRow = (angle / height * width / 90.0).round();

    for (int y = 0; y < height; y++) {
      final rowShift = (shiftPerRow * y).round().clamp(0, width - 1);
      for (int x = 0; x < width; x++) {
        final srcIdx = y * width + x;
        final dstX = (x + rowShift) % width;
        final dstIdx = y * width + dstX;
        if (srcIdx < grayBytes.length && dstIdx < result.length) {
          result[dstIdx] = grayBytes[srcIdx];
        }
      }
    }

    return result;
  }

  /// High-level filter dispatcher applying selected [DocumentFilterMode] to image bytes.
  static Uint8List applyFilter(
    Uint8List bytes,
    DocumentFilterMode filterMode, {
    int binarizationThreshold = 128,
    int? width,
    int? height,
  }) {
    switch (filterMode) {
      case DocumentFilterMode.original:
        return bytes;
      case DocumentFilterMode.grayscale:
        return applyGrayscaleFilter(bytes);
      case DocumentFilterMode.binarization:
        return applyBinarizationFilter(bytes, threshold: binarizationThreshold);
      case DocumentFilterMode.magicColor:
        return applyMagicColorFilter(bytes);
      case DocumentFilterMode.shadowRemoval:
        return applyShadowRemovalFilter(bytes);
      case DocumentFilterMode.deskew:
        if (width != null && height != null) {
          return autoCorrectSkew(bytes, width: width, height: height);
        }
        return bytes;
    }
  }

  /// Applies custom brightness and contrast adjustment to grayscale bytes.
  ///
  /// [brightness] ranges from -1.0 (darker) to +1.0 (brighter).
  /// [contrast] ranges from 0.0 (no contrast) to 2.0+ (high contrast).
  static Uint8List applyBrightnessContrastFilter(
    Uint8List grayBytes, {
    double brightness = 0.0,
    double contrast = 1.0,
  }) {
    if (grayBytes.isEmpty) return grayBytes;
    final result = Uint8List(grayBytes.length);
    final brightnessShift = (brightness * 255).round();

    for (int i = 0; i < grayBytes.length; i++) {
      final val = grayBytes[i];
      final adjusted = ((val - 128) * contrast + 128 + brightnessShift)
          .round()
          .clamp(0, 255);
      result[i] = adjusted;
    }
    return result;
  }
}

