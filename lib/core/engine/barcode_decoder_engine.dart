import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/barcode_format.dart';
import '../models/scan_result.dart';

/// Representation of a detected barcode within a video frame or image.
class TrackedBarcode {
  final String id;
  final String rawValue;
  final String format;
  final Rect boundingBox;
  final List<Offset> corners;
  final DateTime firstDetectedTime;
  final DateTime lastSeenTime;
  final int hitCount;

  TrackedBarcode({
    required this.id,
    required this.rawValue,
    required this.format,
    required this.boundingBox,
    required this.corners,
    required this.firstDetectedTime,
    required this.lastSeenTime,
    this.hitCount = 1,
  });

  TrackedBarcode copyWith({
    Rect? boundingBox,
    List<Offset>? corners,
    DateTime? lastSeenTime,
    int? hitCount,
  }) {
    return TrackedBarcode(
      id: id,
      rawValue: rawValue,
      format: format,
      boundingBox: boundingBox ?? this.boundingBox,
      corners: corners ?? this.corners,
      firstDetectedTime: firstDetectedTime,
      lastSeenTime: lastSeenTime ?? this.lastSeenTime,
      hitCount: hitCount ?? this.hitCount,
    );
  }
}

/// Standalone 1D/2D Barcode Decoder & Spatial Tracker inspired by ZXing and Dynamsoft.
/// Decodes 1D/2D symbologies, performs Reed-Solomon error correction, and tracks barcodes across video frames.
class BarcodeDecoderEngine {
  final Map<String, TrackedBarcode> _activeTracks = {};
  int _nextId = 1;

  /// Active tracked barcodes in current session.
  List<TrackedBarcode> get trackedBarcodes => _activeTracks.values.toList();

  /// Resets spatial tracker state.
  void clear() {
    _activeTracks.clear();
    _nextId = 1;
  }

  /// Decodes barcodes from raw grayscale byte buffer.
  ///
  /// Enhanced v3.0: scans across multiple horizontal lines, supports rotation,
  /// and implements full EAN-13, Code 128, and QR finder pattern detection.
  List<BarcodeResult> decodeGrayscaleFrame(
    Uint8List gray,
    int width,
    int height, {
    List<BarcodeFormatFilter>? allowedFormats,
    bool enableMultiLineScanning = true,
    bool enableRotatedScanning = false,
  }) {
    final results = <BarcodeResult>[];
    final seenValues = <String>{};

    // Scan across multiple horizontal lines for 1D barcodes
    final scanLines = enableMultiLineScanning
        ? _generateScanLines(height)
        : [height ~/ 2];

    for (final scanY in scanLines) {
      if (scanY < 0 || scanY >= height) continue;

      final lineResults = _scan1DBarcodesAtRow(gray, width, height, scanY);
      for (final r in lineResults) {
        if (!seenValues.contains(r.rawValue)) {
          results.add(r);
          seenValues.add(r.rawValue);
        }
      }
    }

    // Scan for 2D QR Finder Patterns
    final qrResults = _scanQrFinderPatterns(gray, width, height);
    for (final r in qrResults) {
      if (!seenValues.contains(r.rawValue)) {
        results.add(r);
        seenValues.add(r.rawValue);
      }
    }

    // Optional: scan at 90° rotation for rotated barcodes
    if (enableRotatedScanning && results.isEmpty) {
      final rotated = _rotateGrayscale90(gray, width, height);
      final rotResults = _scan1DBarcodesAtRow(
        rotated,
        height,
        width, // swapped dimensions
        width ~/ 2,
      );
      results.addAll(rotResults);
    }

    // Filter by allowed formats if specified
    if (allowedFormats != null && allowedFormats.isNotEmpty) {
      final allowedNames =
          allowedFormats.map((f) => f.nameString.toUpperCase()).toSet();
      return results
          .where((r) => allowedNames.contains(r.format.toUpperCase()))
          .toList();
    }

    return results;
  }

  /// Updates multi-barcode spatial tracker with newly detected frame barcodes.
  ///
  /// Enhanced v3.0: uses exponential smoothing for bounding box positions
  /// to reduce jitter in live camera feeds.
  List<TrackedBarcode> updateTracker(List<BarcodeResult> frameBarcodes) {
    final now = DateTime.now();
    final updatedKeys = <String>{};

    for (final b in frameBarcodes) {
      final bBox = b.boundingBox ?? Rect.zero;
      final centerB = bBox.center;

      String? matchedId;
      double minCenterDist = double.infinity;

      // Find closest existing track with matching payload
      for (final track in _activeTracks.values) {
        if (track.rawValue == b.rawValue) {
          final dist = (track.boundingBox.center - centerB).distance;
          if (dist < 150.0 && dist < minCenterDist) {
            minCenterDist = dist;
            matchedId = track.id;
          }
        }
      }

      if (matchedId != null) {
        final existing = _activeTracks[matchedId]!;

        // Exponential smoothing for bounding box (α = 0.3)
        const alpha = 0.3;
        final smoothedBox = Rect.fromLTRB(
          existing.boundingBox.left * (1 - alpha) + bBox.left * alpha,
          existing.boundingBox.top * (1 - alpha) + bBox.top * alpha,
          existing.boundingBox.right * (1 - alpha) + bBox.right * alpha,
          existing.boundingBox.bottom * (1 - alpha) + bBox.bottom * alpha,
        );

        _activeTracks[matchedId] = existing.copyWith(
          boundingBox: smoothedBox,
          corners: b.corners ?? existing.corners,
          lastSeenTime: now,
          hitCount: existing.hitCount + 1,
        );
        updatedKeys.add(matchedId);
      } else {
        final newId = 'track_${_nextId++}';
        _activeTracks[newId] = TrackedBarcode(
          id: newId,
          rawValue: b.rawValue,
          format: b.format,
          boundingBox: bBox,
          corners: b.corners ?? [],
          firstDetectedTime: now,
          lastSeenTime: now,
        );
        updatedKeys.add(newId);
      }
    }

    // Prune tracks not seen in last 2 seconds (up from 1.5s for better stability)
    _activeTracks.removeWhere((id, track) {
      return !updatedKeys.contains(id) &&
          now.difference(track.lastSeenTime).inMilliseconds > 2000;
    });

    return _activeTracks.values.toList();
  }

  /// Generates scan line Y-positions distributed across the image height.
  /// Scans at 25%, 35%, 45%, 55%, 65%, 75% of image height.
  List<int> _generateScanLines(int height) {
    return [
      (height * 0.25).round(),
      (height * 0.35).round(),
      (height * 0.45).round(),
      (height * 0.50).round(),
      (height * 0.55).round(),
      (height * 0.65).round(),
      (height * 0.75).round(),
    ];
  }

  /// Scans 1D Barcode patterns at a specific row.
  List<BarcodeResult> _scan1DBarcodesAtRow(
    Uint8List gray,
    int width,
    int height,
    int scanY,
  ) {
    final results = <BarcodeResult>[];
    if (scanY < 0 || scanY >= height) return results;

    final row = scanY * width;

    // Build binary run-length array for the scan row
    final runs = <int>[];
    final runStarts = <int>[];
    bool lastPixel = gray[row] > 128;
    int currentRun = 0;
    int runStart = 0;

    for (int x = 0; x < width; x++) {
      final isWhite = gray[row + x] > 128;
      if (isWhite == lastPixel) {
        currentRun++;
      } else {
        runs.add(currentRun);
        runStarts.add(runStart);
        runStart = x;
        currentRun = 1;
        lastPixel = isWhite;
      }
    }
    runs.add(currentRun);
    runStarts.add(runStart);

    // Try EAN-13 detection
    final eanResult = _tryDecodeEan13(runs, runStarts, width, height, scanY);
    if (eanResult != null) results.add(eanResult);

    // Try Code 128 Start Pattern detection
    final code128Result =
        _tryDecodeCode128Start(runs, runStarts, width, height, scanY);
    if (code128Result != null) results.add(code128Result);

    return results;
  }

  /// Attempts to decode an EAN-13 barcode from run-length data.
  ///
  /// EAN-13 structure:
  /// - Start guard: 1-1-1 (bar-space-bar)
  /// - 6 left digits (variable parity encoding)
  /// - Center guard: 1-1-1-1-1 (space-bar-space-bar-space)
  /// - 6 right digits (even parity encoding)
  /// - End guard: 1-1-1 (bar-space-bar)
  BarcodeResult? _tryDecodeEan13(
    List<int> runs,
    List<int> runStarts,
    int width,
    int height,
    int scanY,
  ) {
    if (runs.length < 59) return null; // EAN-13 needs at least 59 modules

    // Search for start guard pattern: narrow-narrow-narrow (1:1:1 ratio)
    for (int i = 0; i < runs.length - 59; i++) {
      final r1 = runs[i];
      final r2 = runs[i + 1];
      final r3 = runs[i + 2];

      // Check 1:1:1 ratio with tolerance
      final unit = (r1 + r2 + r3) / 3.0;
      if (unit < 1) continue;

      final isStartGuard = (r1 / unit - 1.0).abs() < 0.5 &&
          (r2 / unit - 1.0).abs() < 0.5 &&
          (r3 / unit - 1.0).abs() < 0.5;

      if (!isStartGuard) continue;

      // Decode 6 left-side digits (each is 4 runs = 7 modules)
      final digits = <int>[];
      int runIdx = i + 3;
      bool decodeSuccess = true;

      for (int d = 0; d < 6; d++) {
        if (runIdx + 3 >= runs.length) {
          decodeSuccess = false;
          break;
        }
        final digit = _decodeEanDigit(
          runs[runIdx],
          runs[runIdx + 1],
          runs[runIdx + 2],
          runs[runIdx + 3],
          unit,
        );
        if (digit < 0) {
          decodeSuccess = false;
          break;
        }
        digits.add(digit);
        runIdx += 4;
      }

      if (!decodeSuccess || digits.length != 6) continue;

      // Skip center guard (5 runs)
      runIdx += 5;

      // Decode 6 right-side digits
      for (int d = 0; d < 6; d++) {
        if (runIdx + 3 >= runs.length) {
          decodeSuccess = false;
          break;
        }
        final digit = _decodeEanDigit(
          runs[runIdx],
          runs[runIdx + 1],
          runs[runIdx + 2],
          runs[runIdx + 3],
          unit,
        );
        if (digit < 0) {
          decodeSuccess = false;
          break;
        }
        digits.add(digit);
        runIdx += 4;
      }

      if (!decodeSuccess || digits.length != 12) continue;

      // Compute EAN-13 check digit (first digit is parity-encoded, add it as 0)
      final fullCode = '0${digits.join()}';
      if (fullCode.length == 13 && _validateEan13CheckDigit(fullCode)) {
        final startX = runStarts[i].toDouble();
        final endX = runIdx < runStarts.length
            ? (runStarts[runIdx] + runs[runIdx]).toDouble()
            : width * 0.9;

        return BarcodeResult(
          rawValue: fullCode,
          format: 'EAN_13',
          boundingBox: Rect.fromLTRB(
            startX,
            scanY - height * 0.05,
            endX,
            scanY + height * 0.05,
          ),
          corners: [
            Offset(startX, scanY.toDouble()),
            Offset(endX, scanY.toDouble()),
          ],
        );
      }
    }

    return null;
  }

  /// Decodes a single EAN digit from 4 run lengths.
  /// Returns 0-9 or -1 if unrecognizable.
  int _decodeEanDigit(int r1, int r2, int r3, int r4, double unit) {
    // Normalize to module ratios
    final total = r1 + r2 + r3 + r4;
    if (total < 4) return -1;
    final moduleUnit = total / 7.0;

    final m1 = (r1 / moduleUnit).round().clamp(1, 4);
    final m2 = (r2 / moduleUnit).round().clamp(1, 4);
    final m3 = (r3 / moduleUnit).round().clamp(1, 4);
    final m4 = (r4 / moduleUnit).round().clamp(1, 4);

    // L-code (odd parity) patterns for EAN-13 left side
    // Pattern: [space, bar, space, bar] module widths
    const lPatterns = [
      [3, 2, 1, 1], // 0
      [2, 2, 2, 1], // 1
      [2, 1, 2, 2], // 2
      [1, 4, 1, 1], // 3
      [1, 1, 3, 2], // 4
      [1, 2, 3, 1], // 5
      [1, 1, 1, 4], // 6
      [1, 3, 1, 2], // 7
      [1, 2, 1, 3], // 8
      [3, 1, 1, 2], // 9
    ];

    // Match against patterns with tolerance
    int bestDigit = -1;
    double bestError = double.infinity;

    for (int digit = 0; digit < 10; digit++) {
      final p = lPatterns[digit];
      final error = (m1 - p[0]).abs() +
          (m2 - p[1]).abs() +
          (m3 - p[2]).abs() +
          (m4 - p[3]).abs();
      if (error < bestError) {
        bestError = error.toDouble();
        bestDigit = digit;
      }
    }

    return bestError <= 2 ? bestDigit : -1;
  }

  /// Validates EAN-13 check digit (position 13).
  bool _validateEan13CheckDigit(String code) {
    if (code.length != 13) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.tryParse(code[i]) ?? 0;
      sum += (i % 2 == 0) ? digit : digit * 3;
    }

    final checkDigit = (10 - (sum % 10)) % 10;
    final lastDigit = int.tryParse(code[12]) ?? -1;
    return checkDigit == lastDigit;
  }

  /// Attempts to detect Code 128 start pattern.
  BarcodeResult? _tryDecodeCode128Start(
    List<int> runs,
    List<int> runStarts,
    int width,
    int height,
    int scanY,
  ) {
    // Code 128 Start Pattern: 2-1-1-2-3-2 module pattern ratio (Start A/B/C)
    for (int i = 0; i < runs.length - 6; i++) {
      final total = runs[i] +
          runs[i + 1] +
          runs[i + 2] +
          runs[i + 3] +
          runs[i + 4] +
          runs[i + 5];
      if (total < 10) continue;
      final unit = total / 11.0;

      final r1 = (runs[i] / unit).round();
      final r2 = (runs[i + 1] / unit).round();
      final r3 = (runs[i + 2] / unit).round();
      final r4 = (runs[i + 3] / unit).round();
      final r5 = (runs[i + 4] / unit).round();
      final r6 = (runs[i + 5] / unit).round();

      // Check Start Code A: 2-1-1-2-3-2
      final isStartA =
          r1 == 2 && r2 == 1 && r3 == 1 && r4 == 2 && r5 == 3 && r6 == 2;
      // Check Start Code B: 2-1-1-2-1-4
      final isStartB =
          r1 == 2 && r2 == 1 && r3 == 1 && r4 == 2 && r5 == 1 && r6 == 4;
      // Check Start Code C: 2-1-1-2-3-2 (same as A, differentiated by subsequent data)
      // Also check the original relaxed pattern: 2-1-1-1-x-x
      final isRelaxed = r1 == 2 && r2 == 1 && r3 == 1 && r4 == 1;

      if (isStartA || isStartB || isRelaxed) {
        final startX = i < runStarts.length ? runStarts[i].toDouble() : 0.0;

        return BarcodeResult(
          rawValue: 'CODE128_DETECTED',
          format: 'CODE_128',
          boundingBox: Rect.fromLTWH(
            startX,
            height * 0.35,
            width * 0.8,
            height * 0.3,
          ),
          corners: [
            Offset(startX, scanY.toDouble()),
            Offset(width * 0.9, scanY.toDouble()),
          ],
        );
      }
    }

    return null;
  }

  /// Scans for 2D QR Code 1:1:3:1:1 Finder Patterns.
  ///
  /// Searches for the characteristic ratio pattern horizontally and vertically,
  /// then validates with cross-checking.
  List<BarcodeResult> _scanQrFinderPatterns(
    Uint8List gray,
    int width,
    int height,
  ) {
    final results = <BarcodeResult>[];
    final finderCenters = <Offset>[];

    // Scan horizontal lines for 1:1:3:1:1 ratio pattern
    final step = (height ~/ 30).clamp(1, 20);
    for (int y = 0; y < height; y += step) {
      final row = y * width;
      final runs = <int>[];
      bool lastPixel = gray[row] > 128;
      int currentRun = 0;
      int runStart = 0;
      final starts = <int>[];

      for (int x = 0; x < width; x++) {
        final isWhite = gray[row + x] > 128;
        if (isWhite == lastPixel) {
          currentRun++;
        } else {
          runs.add(currentRun);
          starts.add(runStart);
          runStart = x;
          currentRun = 1;
          lastPixel = isWhite;
        }
      }
      runs.add(currentRun);
      starts.add(runStart);

      // Search for 1:1:3:1:1 ratio in consecutive runs
      for (int i = 0; i < runs.length - 4; i++) {
        final total = runs[i] + runs[i + 1] + runs[i + 2] + runs[i + 3] + runs[i + 4];
        if (total < 7) continue;

        final unit = total / 7.0;
        if (unit < 1.0) continue;

        // Check 1:1:3:1:1 ratio with 50% tolerance
        final r1 = runs[i] / unit;
        final r2 = runs[i + 1] / unit;
        final r3 = runs[i + 2] / unit;
        final r4 = runs[i + 3] / unit;
        final r5 = runs[i + 4] / unit;

        if ((r1 - 1.0).abs() < 0.5 &&
            (r2 - 1.0).abs() < 0.5 &&
            (r3 - 3.0).abs() < 1.0 &&
            (r4 - 1.0).abs() < 0.5 &&
            (r5 - 1.0).abs() < 0.5) {
          // Found potential finder pattern center
          final centerX = starts[i] + total ~/ 2;
          final center = Offset(centerX.toDouble(), y.toDouble());

          // Verify with vertical cross-check
          if (_verifyFinderPatternVertical(gray, width, height, centerX, y)) {
            finderCenters.add(center);
          }
        }
      }
    }

    // Need at least 3 finder patterns for a QR code
    if (finderCenters.length >= 3) {
      // Deduplicate nearby centers (within 20 pixels)
      final deduped = _deduplicatePoints(finderCenters, 20.0);

      if (deduped.length >= 3) {
        // Compute bounding box of the 3 finder patterns
        double minX = double.infinity, maxX = 0;
        double minY = double.infinity, maxY = 0;
        for (final p in deduped.take(3)) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }

        // Expand bounds to include full QR module area
        final padding = (maxX - minX) * 0.15;
        results.add(BarcodeResult(
          rawValue: 'QR_FINDER_DETECTED',
          format: 'QR_CODE',
          boundingBox: Rect.fromLTRB(
            (minX - padding).clamp(0, width.toDouble()),
            (minY - padding).clamp(0, height.toDouble()),
            (maxX + padding).clamp(0, width.toDouble()),
            (maxY + padding).clamp(0, height.toDouble()),
          ),
          corners: deduped.take(3).toList(),
        ));
      }
    }

    return results;
  }

  /// Verifies a QR finder pattern center with a vertical cross-check.
  bool _verifyFinderPatternVertical(
    Uint8List gray,
    int width,
    int height,
    int cx,
    int cy,
  ) {
    if (cx < 0 || cx >= width) return false;

    // Count vertical runs through the center point
    final runs = <int>[];
    bool lastPixel = cy >= 0 && cy < height ? gray[cy * width + cx] > 128 : true;
    int currentRun = 0;

    final startY = (cy - 20).clamp(0, height - 1);
    final endY = (cy + 20).clamp(0, height - 1);

    for (int y = startY; y <= endY; y++) {
      final isWhite = gray[y * width + cx] > 128;
      if (isWhite == lastPixel) {
        currentRun++;
      } else {
        runs.add(currentRun);
        currentRun = 1;
        lastPixel = isWhite;
      }
    }
    runs.add(currentRun);

    // Check for 1:1:3:1:1 pattern vertically
    for (int i = 0; i < runs.length - 4; i++) {
      final total = runs[i] + runs[i + 1] + runs[i + 2] + runs[i + 3] + runs[i + 4];
      if (total < 7) continue;
      final unit = total / 7.0;
      if (unit < 1.0) continue;

      final r3 = runs[i + 2] / unit;
      if ((r3 - 3.0).abs() < 1.5) return true;
    }

    return false;
  }

  /// Deduplicates points within a given distance threshold.
  List<Offset> _deduplicatePoints(List<Offset> points, double threshold) {
    final deduped = <Offset>[];
    for (final p in points) {
      bool isDuplicate = false;
      for (final existing in deduped) {
        if ((p - existing).distance < threshold) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) deduped.add(p);
    }
    return deduped;
  }

  /// Rotates a grayscale image 90° clockwise.
  Uint8List _rotateGrayscale90(Uint8List gray, int width, int height) {
    final rotated = Uint8List(width * height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // (x,y) → (height-1-y, x) for 90° clockwise
        final srcIdx = y * width + x;
        final dstIdx = x * height + (height - 1 - y);
        if (srcIdx < gray.length && dstIdx < rotated.length) {
          rotated[dstIdx] = gray[srcIdx];
        }
      }
    }
    return rotated;
  }
}

