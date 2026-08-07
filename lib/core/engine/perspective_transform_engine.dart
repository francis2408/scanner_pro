import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/document_scanner_service.dart';

/// Production-grade perspective transform engine implementing 4-point
/// homography via Direct Linear Transform (DLT) with bilinear interpolation.
///
/// Inspired by OpenCV's `cv::getPerspectiveTransform()` + `cv::warpPerspective()`
/// and Scanbot SDK's document perspective correction pipeline.
///
/// This engine:
/// 1. Computes the 3×3 homography matrix from 4 source → 4 destination point pairs
/// 2. Applies inverse mapping with bilinear interpolation for artifact-free warping
/// 3. Provides utility methods for coordinate mapping and ROI extraction
class PerspectiveTransformEngine {
  /// Computes a 3×3 homography matrix mapping 4 source points to 4 destination points
  /// using the Direct Linear Transform (DLT) algorithm.
  ///
  /// The matrix transforms coordinates as:
  /// ```
  /// [x', y', w'] = H × [x, y, 1]
  /// dest = (x'/w', y'/w')
  /// ```
  ///
  /// [src] — 4 source corner points (in any consistent order).
  /// [dst] — 4 destination corner points (typically a rectangle).
  ///
  /// Returns a row-major 3×3 matrix as [Float64List] of length 9.
  static Float64List computeHomography(
    List<Offset> src,
    List<Offset> dst,
  ) {
    assert(src.length == 4 && dst.length == 4);

    // Build the 8×8 system of equations: A × h = b
    // For each point pair (x,y) → (x',y'):
    //   x' = (h0*x + h1*y + h2) / (h6*x + h7*y + 1)
    //   y' = (h3*x + h4*y + h5) / (h6*x + h7*y + 1)
    //
    // Rearranged into linear form:
    //   h0*x + h1*y + h2 - h6*x*x' - h7*y*x' = x'
    //   h3*x + h4*y + h5 - h6*x*y' - h7*y*y' = y'

    final a = Float64List(64); // 8×8 matrix
    final b = Float64List(8);

    for (int i = 0; i < 4; i++) {
      final sx = src[i].dx;
      final sy = src[i].dy;
      final dx = dst[i].dx;
      final dy = dst[i].dy;

      final row1 = i * 2;
      final row2 = row1 + 1;

      // Row for x' equation
      a[row1 * 8 + 0] = sx;
      a[row1 * 8 + 1] = sy;
      a[row1 * 8 + 2] = 1.0;
      a[row1 * 8 + 3] = 0.0;
      a[row1 * 8 + 4] = 0.0;
      a[row1 * 8 + 5] = 0.0;
      a[row1 * 8 + 6] = -sx * dx;
      a[row1 * 8 + 7] = -sy * dx;
      b[row1] = dx;

      // Row for y' equation
      a[row2 * 8 + 0] = 0.0;
      a[row2 * 8 + 1] = 0.0;
      a[row2 * 8 + 2] = 0.0;
      a[row2 * 8 + 3] = sx;
      a[row2 * 8 + 4] = sy;
      a[row2 * 8 + 5] = 1.0;
      a[row2 * 8 + 6] = -sx * dy;
      a[row2 * 8 + 7] = -sy * dy;
      b[row2] = dy;
    }

    // Solve using Gaussian elimination with partial pivoting
    final h = _solveLinearSystem(a, b, 8);

    // Construct 3×3 homography matrix [h0..h7, 1.0]
    return Float64List.fromList([
      h[0], h[1], h[2],
      h[3], h[4], h[5],
      h[6], h[7], 1.0,
    ]);
  }

  /// Computes the homography to warp a detected document quadrilateral
  /// to a flat rectangle of specified dimensions.
  ///
  /// [corners] — Detected document corner points.
  /// [outputWidth], [outputHeight] — Desired output dimensions.
  ///
  /// Returns the 3×3 homography matrix.
  static Float64List computeDocumentHomography(
    DocumentCorners corners, {
    required int outputWidth,
    required int outputHeight,
  }) {
    final src = corners.toList();
    final dst = [
      Offset.zero,
      Offset(outputWidth.toDouble(), 0),
      Offset(outputWidth.toDouble(), outputHeight.toDouble()),
      Offset(0, outputHeight.toDouble()),
    ];

    return computeHomography(src, dst);
  }

  /// Warps a grayscale image using the given homography matrix with
  /// bilinear interpolation for sub-pixel accuracy.
  ///
  /// [gray] — Source grayscale image buffer (1 byte per pixel).
  /// [srcWidth], [srcHeight] — Source image dimensions.
  /// [homography] — 3×3 homography matrix from [computeHomography].
  /// [dstWidth], [dstHeight] — Output image dimensions.
  /// [backgroundColor] — Fill color for pixels outside source bounds (default: 255 white).
  ///
  /// Returns the warped image as a [Uint8List].
  static Uint8List warpPerspective(
    Uint8List gray,
    int srcWidth,
    int srcHeight,
    Float64List homography,
    int dstWidth,
    int dstHeight, {
    int backgroundColor = 255,
  }) {
    final output = Uint8List(dstWidth * dstHeight);
    if (backgroundColor != 0) {
      output.fillRange(0, output.length, backgroundColor);
    }

    // Compute inverse homography for backward mapping (destination → source)
    final invH = _invertHomography(homography);
    if (invH == null) return output;

    for (int dy = 0; dy < dstHeight; dy++) {
      for (int dx = 0; dx < dstWidth; dx++) {
        // Map destination pixel back to source coordinates
        final dxf = dx.toDouble();
        final dyf = dy.toDouble();

        final w = invH[6] * dxf + invH[7] * dyf + invH[8];
        if (w.abs() < 1e-10) continue;

        final sx = (invH[0] * dxf + invH[1] * dyf + invH[2]) / w;
        final sy = (invH[3] * dxf + invH[4] * dyf + invH[5]) / w;

        // Bilinear interpolation for sub-pixel accuracy
        if (sx >= 0 && sx < srcWidth - 1 && sy >= 0 && sy < srcHeight - 1) {
          output[dy * dstWidth + dx] = _bilinearSample(
            gray,
            srcWidth,
            srcHeight,
            sx,
            sy,
          );
        }
      }
    }

    return output;
  }

  /// Warps a document image from detected quad corners to a flat rectangle.
  ///
  /// High-level convenience API combining homography computation and warping.
  ///
  /// [gray] — Source grayscale image.
  /// [srcWidth], [srcHeight] — Source dimensions.
  /// [corners] — Detected document corner points.
  /// [outputWidth], [outputHeight] — Desired output dimensions.
  ///   If null, auto-computed from the detected quad's dimensions.
  ///
  /// Returns the flattened document image as a [PerspectiveWarpResult].
  static PerspectiveWarpResult warpDocument(
    Uint8List gray,
    int srcWidth,
    int srcHeight,
    DocumentCorners corners, {
    int? outputWidth,
    int? outputHeight,
  }) {
    // Auto-compute output dimensions from quad edge lengths
    final topEdge = (corners.topRight - corners.topLeft).distance;
    final bottomEdge = (corners.bottomRight - corners.bottomLeft).distance;
    final leftEdge = (corners.bottomLeft - corners.topLeft).distance;
    final rightEdge = (corners.bottomRight - corners.topRight).distance;

    final outW = outputWidth ?? math.max(topEdge, bottomEdge).round();
    final outH = outputHeight ?? math.max(leftEdge, rightEdge).round();

    // Clamp to reasonable bounds
    final clampedW = outW.clamp(100, 4096);
    final clampedH = outH.clamp(100, 4096);

    final homography = computeDocumentHomography(
      corners,
      outputWidth: clampedW,
      outputHeight: clampedH,
    );

    final warped = warpPerspective(
      gray,
      srcWidth,
      srcHeight,
      homography,
      clampedW,
      clampedH,
    );

    return PerspectiveWarpResult(
      bytes: warped,
      width: clampedW,
      height: clampedH,
      homography: homography,
      sourceCorners: corners,
    );
  }

  /// Maps a single point through the homography transformation.
  ///
  /// Useful for coordinate mapping between source and destination spaces.
  static Offset transformPoint(Float64List homography, Offset point) {
    final x = point.dx;
    final y = point.dy;
    final w = homography[6] * x + homography[7] * y + homography[8];

    if (w.abs() < 1e-10) return point;

    return Offset(
      (homography[0] * x + homography[1] * y + homography[2]) / w,
      (homography[3] * x + homography[4] * y + homography[5]) / w,
    );
  }

  /// Converts a [Float64List] homography to a Flutter [Matrix4] for use in
  /// CustomPainter transforms and widget rendering.
  static Matrix4 homographyToMatrix4(Float64List h) {
    return Matrix4(
      h[0], h[3], 0, h[6],
      h[1], h[4], 0, h[7],
      0, 0, 1, 0,
      h[2], h[5], 0, h[8],
    );
  }

  // --- Internal helpers ---

  /// Bilinear interpolation sampling from grayscale image.
  static int _bilinearSample(
    Uint8List gray,
    int width,
    int height,
    double x,
    double y,
  ) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    if (x0 < 0 || x1 >= width || y0 < 0 || y1 >= height) {
      return 255; // Background
    }

    final fx = x - x0;
    final fy = y - y0;

    final p00 = gray[y0 * width + x0];
    final p10 = gray[y0 * width + x1];
    final p01 = gray[y1 * width + x0];
    final p11 = gray[y1 * width + x1];

    final val = p00 * (1 - fx) * (1 - fy) +
        p10 * fx * (1 - fy) +
        p01 * (1 - fx) * fy +
        p11 * fx * fy;

    return val.round().clamp(0, 255);
  }

  /// Inverts a 3×3 homography matrix.
  static Float64List? _invertHomography(Float64List h) {
    // Compute determinant
    final det = h[0] * (h[4] * h[8] - h[5] * h[7]) -
        h[1] * (h[3] * h[8] - h[5] * h[6]) +
        h[2] * (h[3] * h[7] - h[4] * h[6]);

    if (det.abs() < 1e-10) return null;

    final invDet = 1.0 / det;

    return Float64List.fromList([
      (h[4] * h[8] - h[5] * h[7]) * invDet,
      (h[2] * h[7] - h[1] * h[8]) * invDet,
      (h[1] * h[5] - h[2] * h[4]) * invDet,
      (h[5] * h[6] - h[3] * h[8]) * invDet,
      (h[0] * h[8] - h[2] * h[6]) * invDet,
      (h[2] * h[3] - h[0] * h[5]) * invDet,
      (h[3] * h[7] - h[4] * h[6]) * invDet,
      (h[1] * h[6] - h[0] * h[7]) * invDet,
      (h[0] * h[4] - h[1] * h[3]) * invDet,
    ]);
  }

  /// Gaussian elimination with partial pivoting for solving Ax = b.
  static Float64List _solveLinearSystem(
    Float64List a,
    Float64List b,
    int n,
  ) {
    // Create augmented matrix [A|b]
    final aug = Float64List(n * (n + 1));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        aug[i * (n + 1) + j] = a[i * n + j];
      }
      aug[i * (n + 1) + n] = b[i];
    }

    // Forward elimination with partial pivoting
    for (int col = 0; col < n; col++) {
      // Find pivot row
      int pivotRow = col;
      double pivotVal = aug[col * (n + 1) + col].abs();
      for (int row = col + 1; row < n; row++) {
        final val = aug[row * (n + 1) + col].abs();
        if (val > pivotVal) {
          pivotVal = val;
          pivotRow = row;
        }
      }

      // Swap rows
      if (pivotRow != col) {
        for (int j = 0; j <= n; j++) {
          final temp = aug[col * (n + 1) + j];
          aug[col * (n + 1) + j] = aug[pivotRow * (n + 1) + j];
          aug[pivotRow * (n + 1) + j] = temp;
        }
      }

      final pivot = aug[col * (n + 1) + col];
      if (pivot.abs() < 1e-12) continue;

      // Eliminate below
      for (int row = col + 1; row < n; row++) {
        final factor = aug[row * (n + 1) + col] / pivot;
        for (int j = col; j <= n; j++) {
          aug[row * (n + 1) + j] -= factor * aug[col * (n + 1) + j];
        }
      }
    }

    // Back substitution
    final x = Float64List(n);
    for (int i = n - 1; i >= 0; i--) {
      double sum = aug[i * (n + 1) + n];
      for (int j = i + 1; j < n; j++) {
        sum -= aug[i * (n + 1) + j] * x[j];
      }
      final diag = aug[i * (n + 1) + i];
      x[i] = diag.abs() > 1e-12 ? sum / diag : 0.0;
    }

    return x;
  }
}

/// Result of perspective warp operation.
class PerspectiveWarpResult {
  /// Warped (flattened) grayscale image bytes.
  final Uint8List bytes;

  /// Output image width.
  final int width;

  /// Output image height.
  final int height;

  /// The 3×3 homography matrix used for the warp.
  final Float64List homography;

  /// Original source document corners.
  final DocumentCorners sourceCorners;

  const PerspectiveWarpResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.homography,
    required this.sourceCorners,
  });
}
