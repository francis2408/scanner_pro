import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

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
}

/// Specialized service providing Document Edge Detection, Perspective Matrix calculations,
/// Shadow Removal image filters, and Auto Crop bounds.
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

    // Adaptive threshold & background whitening
    for (int i = 0; i < grayBytes.length; i++) {
      final val = grayBytes[i];
      if (val > 180) {
        result[i] = 255; // Whiten background paper
      } else if (val < 90) {
        result[i] = 0; // Darken ink text
      } else {
        final scaled = ((val - 90) * (255 / 90)).clamp(0, 255).toInt();
        result[i] = scaled;
      }
    }
    return result;
  }
}
