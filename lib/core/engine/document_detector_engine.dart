import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../services/document_scanner_service.dart';
import 'contour_detector.dart';

/// Advanced document edge and quadrilateral detection engine inspired by OpenCV & Scanbot SDK.
///
/// v3.0 upgrade: Now uses the full Canny → Contour → Quad pipeline:
/// 1. Canny edge detection for robust edge extraction
/// 2. Connected component contour tracing
/// 3. Douglas-Peucker polygon simplification
/// 4. Convex hull → best quadrilateral selection
/// 5. Multi-candidate ranking with scoring
/// 6. Sobel gradient fallback for simple scenes
class DocumentDetectorEngine {
  /// Detects document quad corners from grayscale byte buffer.
  ///
  /// Enhanced v3.0: Uses Canny + contour-based quad detection with
  /// multi-candidate ranking and fallback to Sobel gradient method.
  static DocumentCorners detectQuadrilateral(
    Uint8List gray,
    int width,
    int height, {
    double minAreaRatio = 0.15,
    int candidateCount = 5,
  }) {
    if (gray.length < width * height || width < 10 || height < 10) {
      return DocumentScannerService.detectDocumentEdges(
        Size(width.toDouble(), height.toDouble()),
      );
    }

    // Strategy 1: Canny + Contour-based detection (primary)
    final contourQuad = ContourDetector.detectDocumentQuad(
      gray,
      width,
      height,
      candidateCount: candidateCount,
      minAreaRatio: minAreaRatio,
    );

    // Check if the contour detector found a valid quad (not the default inset)
    final totalArea = (width * height).toDouble();
    final defaultInset = DocumentScannerService.detectDocumentEdges(
      Size(width.toDouble(), height.toDouble()),
    );
    if (contourQuad.area > totalArea * minAreaRatio &&
        _cornersAreDifferent(contourQuad, defaultInset)) {
      return contourQuad;
    }

    // Strategy 2: Sobel gradient fallback (for high-contrast documents)
    final sobelQuad = _detectViaSobelGradient(gray, width, height, minAreaRatio);
    if (sobelQuad != null && sobelQuad.isValidQuad) {
      return sobelQuad;
    }

    // Default fallback to 8% inset bounding box
    return defaultInset;
  }

  /// Sorts 4 arbitrary points into Top-Left, Top-Right, Bottom-Right, Bottom-Left order.
  static DocumentCorners sortCorners(List<Offset> points) {
    if (points.length != 4) {
      return const DocumentCorners(
        topLeft: Offset.zero,
        topRight: Offset(100, 0),
        bottomRight: Offset(100, 100),
        bottomLeft: Offset(0, 100),
      );
    }

    // Sort by sum of (x + y): Top-Left has smallest sum, Bottom-Right has largest sum.
    final sums = points.map((p) => p.dx + p.dy).toList();
    final diffs = points.map((p) => p.dy - p.dx).toList();

    int tlIdx = 0, brIdx = 0, trIdx = 0, blIdx = 0;
    double minSum = double.infinity, maxSum = -double.infinity;
    double minDiff = double.infinity, maxDiff = -double.infinity;

    for (int i = 0; i < 4; i++) {
      if (sums[i] < minSum) {
        minSum = sums[i];
        tlIdx = i;
      }
      if (sums[i] > maxSum) {
        maxSum = sums[i];
        brIdx = i;
      }
      if (diffs[i] < minDiff) {
        minDiff = diffs[i];
        trIdx = i;
      }
      if (diffs[i] > maxDiff) {
        maxDiff = diffs[i];
        blIdx = i;
      }
    }

    return DocumentCorners(
      topLeft: points[tlIdx],
      topRight: points[trIdx],
      bottomRight: points[brIdx],
      bottomLeft: points[blIdx],
    );
  }

  /// Calculates skew angle of detected document quad in degrees.
  static double detectSkewAngle(DocumentCorners corners) {
    final topDx = corners.topRight.dx - corners.topLeft.dx;
    final topDy = corners.topRight.dy - corners.topLeft.dy;
    final rad = math.atan2(topDy, topDx);
    return rad * (180.0 / math.pi);
  }

  /// Computes document coverage ratio (quad area / frame area).
  ///
  /// Useful for auto-capture: ensures document fills sufficient frame area.
  static double computeCoverageRatio(
    DocumentCorners corners,
    int imageWidth,
    int imageHeight,
  ) {
    final frameArea = (imageWidth * imageHeight).toDouble();
    return frameArea > 0 ? corners.area / frameArea : 0.0;
  }

  /// Detects specular glare/highlights in a grayscale image.
  ///
  /// Returns the fraction of pixels exceeding the brightness threshold.
  /// Values > 0.03 indicate significant glare.
  static double detectGlare(
    Uint8List gray,
    int width,
    int height, {
    int brightnessThreshold = 245,
  }) {
    if (gray.isEmpty) return 0.0;

    int hotPixels = 0;
    final step = math.max(1, gray.length ~/ 2000);
    int sampled = 0;

    for (int i = 0; i < gray.length; i += step) {
      if (gray[i] >= brightnessThreshold) hotPixels++;
      sampled++;
    }

    return sampled > 0 ? hotPixels / sampled : 0.0;
  }

  /// Computes Sobel Gradient Magnitude and finds quad via bounding box.
  ///
  /// Retained as a fast fallback for high-contrast documents.
  static DocumentCorners? _detectViaSobelGradient(
    Uint8List gray,
    int width,
    int height,
    double minAreaRatio,
  ) {
    final totalArea = (width * height).toDouble();
    final minArea = totalArea * minAreaRatio;

    final edgeMap = _computeSobelEdges(gray, width, height);

    int minX = width, maxX = 0, minY = height, maxY = 0;
    int count = 0;

    for (int y = 0; y < height; y += 4) {
      final row = y * width;
      for (int x = 0; x < width; x += 4) {
        if (edgeMap[row + x] > 0) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
          count++;
        }
      }
    }

    if (count < 20 || (maxX - minX) * (maxY - minY) < minArea) {
      return null;
    }

    final corners = sortCorners([
      Offset(minX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), minY.toDouble()),
      Offset(maxX.toDouble(), maxY.toDouble()),
      Offset(minX.toDouble(), maxY.toDouble()),
    ]);

    return corners.area >= minArea ? corners : null;
  }

  /// Computes Sobel Gradient Magnitude.
  static Uint8List _computeSobelEdges(Uint8List gray, int width, int height) {
    final edges = Uint8List(width * height);
    final stride = width;

    for (int y = 1; y < height - 1; y += 2) {
      final row = y * stride;
      for (int x = 1; x < width - 1; x += 2) {
        final idx = row + x;
        // Sobel X kernel: [-1 0 1; -2 0 2; -1 0 1]
        final gx = (gray[idx - stride + 1] + 2 * gray[idx + 1] + gray[idx + stride + 1]) -
            (gray[idx - stride - 1] + 2 * gray[idx - 1] + gray[idx + stride - 1]);

        // Sobel Y kernel: [-1 -2 -1; 0 0 0; 1 2 1]
        final gy = (gray[idx + stride - 1] + 2 * gray[idx + stride] + gray[idx + stride + 1]) -
            (gray[idx - stride - 1] + 2 * gray[idx - stride] + gray[idx - stride + 1]);

        final mag = math.min(255, (gx.abs() + gy.abs()) ~/ 2);
        edges[idx] = mag > 35 ? 255 : 0;
      }
    }
    return edges;
  }

  /// Checks if two DocumentCorners are meaningfully different.
  static bool _cornersAreDifferent(DocumentCorners a, DocumentCorners b) {
    const threshold = 10.0;
    return (a.topLeft - b.topLeft).distance > threshold ||
        (a.topRight - b.topRight).distance > threshold ||
        (a.bottomRight - b.bottomRight).distance > threshold ||
        (a.bottomLeft - b.bottomLeft).distance > threshold;
  }
}

