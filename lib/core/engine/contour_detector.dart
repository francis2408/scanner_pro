import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/document_scanner_service.dart';
import 'canny_edge_detector.dart';

/// Contour detection and polygon simplification engine implemented in pure Dart.
///
/// Inspired by OpenCV's `findContours()` + `approxPolyDP()` and Scanbot SDK's
/// document quad detection pipeline:
/// 1. Connected component labeling (Union-Find)
/// 2. Contour boundary tracing (Moore-Neighbor / Suzuki-Abe inspired)
/// 3. Douglas-Peucker polygon simplification
/// 4. Convex hull computation (Graham scan)
/// 5. Best quadrilateral selection
class ContourDetector {
  /// Detects all contours in a binary edge map.
  ///
  /// [edgeMap] — Binary image (0 or 255 per pixel) from Canny or binarization.
  /// [width], [height] — Image dimensions.
  /// [minContourLength] — Minimum number of points in a valid contour.
  ///
  /// Returns a list of contours, each represented as a list of [Offset] points.
  static List<List<Offset>> findContours(
    Uint8List edgeMap,
    int width,
    int height, {
    int minContourLength = 20,
  }) {
    if (edgeMap.length < width * height || width < 3 || height < 3) {
      return [];
    }

    final contours = <List<Offset>>[];
    final visited = Uint8List(width * height);

    // Moore-Neighbor boundary tracing
    // 8-connectivity neighbor offsets (clockwise from East)
    const dx = [1, 1, 0, -1, -1, -1, 0, 1];
    const dy = [0, 1, 1, 1, 0, -1, -1, -1];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;

        // Look for unvisited edge pixel with non-edge pixel to its left
        // (contour entry point: transition from background to edge)
        if (edgeMap[idx] == 0 || visited[idx] != 0) continue;
        if (edgeMap[idx - 1] != 0) continue; // Must be a boundary pixel

        final contour = <Offset>[];
        int cx = x, cy = y;
        int startDir = 0; // Start searching from East

        // Trace the contour boundary
        int maxSteps = width * height; // Safety limit
        bool firstPixel = true;

        do {
          contour.add(Offset(cx.toDouble(), cy.toDouble()));
          visited[cy * width + cx] = 1;

          // Search 8-connected neighbors for next boundary pixel
          bool found = false;
          final searchStart = (startDir + 5) % 8; // Backtrack direction + 1

          for (int i = 0; i < 8; i++) {
            final dir = (searchStart + i) % 8;
            final nx = cx + dx[dir];
            final ny = cy + dy[dir];

            if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;

            if (edgeMap[ny * width + nx] != 0) {
              cx = nx;
              cy = ny;
              startDir = dir;
              found = true;
              break;
            }
          }

          if (!found) break;
          if (firstPixel) firstPixel = false;
          maxSteps--;
        } while ((cx != x || cy != y) && maxSteps > 0);

        if (contour.length >= minContourLength) {
          contours.add(contour);
        }
      }
    }

    // Sort by contour length (largest first)
    contours.sort((a, b) => b.length.compareTo(a.length));

    return contours;
  }

  /// Simplifies a contour using the Douglas-Peucker algorithm.
  ///
  /// Reduces the number of points in a polyline while preserving shape.
  /// [epsilon] controls approximation accuracy (higher = more simplification).
  ///
  /// Inspired by OpenCV's `cv::approxPolyDP()`.
  static List<Offset> simplifyPolygon(List<Offset> contour, double epsilon) {
    if (contour.length <= 2) return List.from(contour);

    // Find the point with maximum perpendicular distance from the line
    // connecting the first and last points
    double maxDist = 0;
    int maxIdx = 0;
    final first = contour.first;
    final last = contour.last;

    for (int i = 1; i < contour.length - 1; i++) {
      final dist = _perpendicularDistance(contour[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        maxIdx = i;
      }
    }

    if (maxDist > epsilon) {
      // Recursively simplify both halves
      final left = simplifyPolygon(contour.sublist(0, maxIdx + 1), epsilon);
      final right = simplifyPolygon(contour.sublist(maxIdx), epsilon);

      // Concatenate (removing duplicate junction point)
      return [...left.sublist(0, left.length - 1), ...right];
    }

    // All points are within epsilon — return just endpoints
    return [first, last];
  }

  /// Computes the convex hull of a set of points using the Graham scan algorithm.
  ///
  /// Returns the convex hull vertices in counter-clockwise order.
  static List<Offset> convexHull(List<Offset> points) {
    if (points.length <= 3) return List.from(points);

    // Find the lowest point (ties broken by leftmost)
    int lowestIdx = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].dy > points[lowestIdx].dy ||
          (points[i].dy == points[lowestIdx].dy &&
              points[i].dx < points[lowestIdx].dx)) {
        lowestIdx = i;
      }
    }

    // Swap lowest point to front
    final sorted = List<Offset>.from(points);
    final pivot = sorted[lowestIdx];
    sorted[lowestIdx] = sorted[0];
    sorted[0] = pivot;

    // Sort by polar angle relative to pivot
    sorted.sort((a, b) {
      if (a == pivot) return -1;
      if (b == pivot) return 1;
      final cross = _crossProduct(pivot, a, b);
      if (cross == 0) {
        // Collinear: sort by distance
        return (a - pivot).distanceSquared.compareTo((b - pivot).distanceSquared);
      }
      return cross > 0 ? -1 : 1;
    });

    // Graham scan
    final hull = <Offset>[];
    for (final p in sorted) {
      while (hull.length >= 2 &&
          _crossProduct(hull[hull.length - 2], hull.last, p) <= 0) {
        hull.removeLast();
      }
      hull.add(p);
    }

    return hull;
  }

  /// Finds the best quadrilateral approximation from a contour.
  ///
  /// Uses iterative Douglas-Peucker simplification with decreasing epsilon
  /// until a 4-vertex polygon is found, then validates convexity and area.
  ///
  /// Returns null if no valid quadrilateral can be extracted.
  static DocumentCorners? findBestQuadrilateral(
    List<Offset> contour,
    int imageWidth,
    int imageHeight, {
    double minAreaRatio = 0.1,
    double maxAreaRatio = 0.95,
  }) {
    if (contour.length < 4) return null;

    final totalArea = (imageWidth * imageHeight).toDouble();
    final minArea = totalArea * minAreaRatio;
    final maxArea = totalArea * maxAreaRatio;

    // Compute contour perimeter for epsilon scaling
    double perimeter = 0;
    for (int i = 0; i < contour.length; i++) {
      final next = (i + 1) % contour.length;
      perimeter += (contour[next] - contour[i]).distance;
    }

    // Try progressively tighter epsilon values to find a 4-sided polygon
    for (double epsilonFactor = 0.04;
        epsilonFactor >= 0.01;
        epsilonFactor -= 0.005) {
      final epsilon = perimeter * epsilonFactor;
      final simplified = simplifyPolygon(contour, epsilon);

      if (simplified.length == 4) {
        final corners = _sortCorners(simplified);
        if (corners == null) continue;

        final area = corners.area;
        if (area >= minArea && area <= maxArea && corners.isValidQuad) {
          return corners;
        }
      }
    }

    // Fallback: try convex hull → quad approximation
    final hull = convexHull(contour);
    if (hull.length >= 4) {
      final quadPoints = _approximateQuadFromHull(hull);
      if (quadPoints != null) {
        final corners = _sortCorners(quadPoints);
        if (corners != null) {
          final area = corners.area;
          if (area >= minArea && area <= maxArea && corners.isValidQuad) {
            return corners;
          }
        }
      }
    }

    return null;
  }

  /// Detects the best document quadrilateral from a grayscale image.
  ///
  /// This is the high-level API that chains:
  /// Canny edge detection → contour finding → quad extraction → corner sorting.
  ///
  /// [gray] — Single-channel grayscale pixel buffer.
  /// [width], [height] — Image dimensions.
  /// [candidateCount] — Number of top contour candidates to evaluate.
  ///
  /// Returns the best [DocumentCorners] found, or a default inset quad
  /// if no valid document edges are detected.
  static DocumentCorners detectDocumentQuad(
    Uint8List gray,
    int width,
    int height, {
    int candidateCount = 5,
    double minAreaRatio = 0.15,
  }) {
    // Stage 1: Canny edge detection
    final edges = CannyEdgeDetector.detect(
      gray,
      width,
      height,
      useAutoThreshold: true,
    );

    // Stage 2: Find contours
    final contours = findContours(edges, width, height, minContourLength: 40);

    // Stage 3: Evaluate top candidates for best quadrilateral
    DocumentCorners? bestQuad;
    double bestScore = 0;

    final evalCount = math.min(candidateCount, contours.length);
    for (int i = 0; i < evalCount; i++) {
      final quad = findBestQuadrilateral(
        contours[i],
        width,
        height,
        minAreaRatio: minAreaRatio,
      );

      if (quad != null) {
        final score = _scoreQuadrilateral(quad, width, height);
        if (score > bestScore) {
          bestScore = score;
          bestQuad = quad;
        }
      }
    }

    // Return best quad or default inset
    return bestQuad ??
        DocumentScannerService.detectDocumentEdges(
          Size(width.toDouble(), height.toDouble()),
        );
  }

  /// Scores a quadrilateral based on multiple quality criteria.
  ///
  /// Higher score = better document quad candidate.
  /// Criteria (inspired by Scanbot SDK):
  /// - Area coverage ratio (larger is better, up to 90%)
  /// - Aspect ratio similarity to common document ratios
  /// - Edge straightness (internal angles close to 90°)
  /// - Convexity (must be convex)
  static double _scoreQuadrilateral(
    DocumentCorners quad,
    int imageWidth,
    int imageHeight,
  ) {
    final totalArea = (imageWidth * imageHeight).toDouble();
    final quadArea = quad.area;

    // Score 1: Area coverage (0.0 to 1.0, penalize too small or too large)
    final areaRatio = quadArea / totalArea;
    final areaScore = areaRatio < 0.15
        ? 0.0
        : areaRatio > 0.95
            ? 0.5
            : math.min(1.0, areaRatio / 0.7);

    // Score 2: Aspect ratio (common documents: ~1.41 for A4, ~1.29 for Letter)
    final ar = quad.aspectRatio;
    final arDistance = math.min(
      (ar - 1.414).abs(), // A4
      math.min(
        (ar - 1.294).abs(), // US Letter
        math.min(
          (ar - 1.0).abs(), // Square
          (ar - 0.707).abs(), // Portrait A4
        ),
      ),
    );
    final arScore = (1.0 - arDistance / 2.0).clamp(0.0, 1.0);

    // Score 3: Internal angles (sum should be 360°, each close to 90°)
    final corners = quad.toList();
    double angleScore = 1.0;
    for (int i = 0; i < 4; i++) {
      final p0 = corners[(i + 3) % 4];
      final p1 = corners[i];
      final p2 = corners[(i + 1) % 4];
      final angle = _angleBetween(p0, p1, p2);
      final deviation = (angle - 90.0).abs();
      angleScore -= deviation / 360.0; // Penalize deviation from 90°
    }
    angleScore = angleScore.clamp(0.0, 1.0);

    // Score 4: Convexity bonus
    final convexityScore = quad.isConvex ? 1.0 : 0.3;

    // Weighted combination
    return (areaScore * 0.35 +
            arScore * 0.15 +
            angleScore * 0.35 +
            convexityScore * 0.15)
        .clamp(0.0, 1.0);
  }

  /// Approximates a 4-sided polygon from a convex hull with more than 4 vertices.
  ///
  /// Selects the 4 vertices that maximize the enclosed area.
  static List<Offset>? _approximateQuadFromHull(List<Offset> hull) {
    if (hull.length < 4) return null;
    if (hull.length == 4) return hull;

    // For small hulls, try all combinations
    if (hull.length <= 10) {
      List<Offset>? bestQuad;
      double bestArea = 0;

      for (int a = 0; a < hull.length; a++) {
        for (int b = a + 1; b < hull.length; b++) {
          for (int c = b + 1; c < hull.length; c++) {
            for (int d = c + 1; d < hull.length; d++) {
              final quad = [hull[a], hull[b], hull[c], hull[d]];
              final area = _polygonArea(quad);
              if (area > bestArea) {
                bestArea = area;
                bestQuad = quad;
              }
            }
          }
        }
      }

      return bestQuad;
    }

    // For large hulls, use heuristic: pick 4 points at roughly equal spacing
    final step = hull.length / 4.0;
    return [
      hull[0],
      hull[(step * 1).round() % hull.length],
      hull[(step * 2).round() % hull.length],
      hull[(step * 3).round() % hull.length],
    ];
  }

  /// Sorts 4 points into DocumentCorners (TL, TR, BR, BL) order.
  static DocumentCorners? _sortCorners(List<Offset> points) {
    if (points.length != 4) return null;

    // Sort by sum (x+y): smallest = TL, largest = BR
    // Sort by diff (y-x): smallest = TR, largest = BL
    final sorted = List<Offset>.from(points);

    final sums = sorted.map((p) => p.dx + p.dy).toList();
    final diffs = sorted.map((p) => p.dy - p.dx).toList();

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
      topLeft: sorted[tlIdx],
      topRight: sorted[trIdx],
      bottomRight: sorted[brIdx],
      bottomLeft: sorted[blIdx],
    );
  }

  /// Perpendicular distance from point [p] to line segment [a]–[b].
  static double _perpendicularDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq == 0) return (p - a).distance;

    final numerator = ((p.dx - a.dx) * dy - (p.dy - a.dy) * dx).abs();
    return numerator / math.sqrt(lengthSq);
  }

  /// Cross product of vectors (b-a) and (c-a).
  static double _crossProduct(Offset a, Offset b, Offset c) {
    return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  }

  /// Shoelace formula for polygon area.
  static double _polygonArea(List<Offset> points) {
    double sum1 = 0, sum2 = 0;
    for (int i = 0; i < points.length; i++) {
      final next = (i + 1) % points.length;
      sum1 += points[i].dx * points[next].dy;
      sum2 += points[i].dy * points[next].dx;
    }
    return (sum1 - sum2).abs() / 2.0;
  }

  /// Angle at vertex p1 formed by edges p0-p1 and p1-p2, in degrees.
  static double _angleBetween(Offset p0, Offset p1, Offset p2) {
    final v1 = p0 - p1;
    final v2 = p2 - p1;
    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final cross = v1.dx * v2.dy - v1.dy * v2.dx;
    final angle = math.atan2(cross.abs(), dot);
    return angle * 180.0 / math.pi;
  }
}
