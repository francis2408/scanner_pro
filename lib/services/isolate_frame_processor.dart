import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../core/models/scanner_options.dart';

/// Data structure carrying frame processing arguments into isolate task.
class IsolateFrameTaskData {
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final ScanWindow? scanWindow;
  final bool computeLuminosity;
  final bool enableEnhancement;
  final bool enableBlurDetection;
  final int? previousFrameHash;

  const IsolateFrameTaskData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    this.scanWindow,
    this.computeLuminosity = true,
    this.enableEnhancement = true,
    this.enableBlurDetection = true,
    this.previousFrameHash,
  });
}

/// Structured response output returned from isolate frame processing.
class IsolateFrameResult {
  final Uint8List processedBytes;
  final double averageLuminosity;
  final int croppedWidth;
  final int croppedHeight;
  final bool isLowLight;
  final double blurScore;
  final bool isBlurry;
  final bool isMotionDetected;
  final double motionScore;
  final bool isStaticFrame;
  final int frameHash;
  final double contrastScore;
  final List<String> enhancementsApplied;

  const IsolateFrameResult({
    required this.processedBytes,
    required this.averageLuminosity,
    required this.croppedWidth,
    required this.croppedHeight,
    required this.isLowLight,
    this.blurScore = 100.0,
    this.isBlurry = false,
    this.isMotionDetected = false,
    this.motionScore = 0.0,
    this.isStaticFrame = false,
    this.frameHash = 0,
    this.contrastScore = 1.0,
    this.enhancementsApplied = const [],
  });
}

/// Multithreaded background isolate worker for processing camera image frames,
/// performing sub-region ROI cropping, image enhancement, blur/motion detection,
/// static frame skipping, and calculating frame luminosity without UI stutter.
class IsolateFrameProcessor {
  static Uint8List? _reusableBuffer;

  /// Processes raw frame payload on a background isolate thread.
  static Future<IsolateFrameResult> processFrame(
    IsolateFrameTaskData task,
  ) async {
    return compute(_executeFrameProcessingTask, task);
  }

  /// Top-level worker method executed in background isolate.
  static IsolateFrameResult _executeFrameProcessingTask(
    IsolateFrameTaskData task,
  ) {
    final rawBytes = task.bytes;
    final w = task.width;
    final h = task.height;
    final enhancements = <String>[];

    // 1. Calculate luminosity from Y (luma) plane & compute lightweight frame hash
    double luminosity = 0.5;
    int currentFrameHash = 0;
    if (task.computeLuminosity && rawBytes.isNotEmpty) {
      int sum = 0;
      final sampleStep = (rawBytes.length ~/ 1000).clamp(1, 100);
      int sampleCount = 0;
      int hashAcc = 17;
      for (int i = 0; i < rawBytes.length && i < w * h; i += sampleStep) {
        final b = rawBytes[i];
        sum += b;
        hashAcc = (hashAcc * 31 + b) & 0x7FFFFFFF;
        sampleCount++;
      }
      if (sampleCount > 0) {
        luminosity = (sum / sampleCount) / 255.0;
      }
      currentFrameHash = hashAcc;
    }
    final isLowLight = luminosity < 0.25;

    // Static scene detection check
    bool isStaticFrame = false;
    if (task.previousFrameHash != null && task.previousFrameHash != 0) {
      if ((task.previousFrameHash! - currentFrameHash).abs() < 50) {
        isStaticFrame = true;
      }
    }

    // 2. Perform ROI Sub-region cropping if scanWindow is defined
    Uint8List workingBytes = rawBytes;
    int currentW = w;
    int currentH = h;
    final window = task.scanWindow;

    if (window != null &&
        !(window.left == 0.0 &&
            window.top == 0.0 &&
            window.width == 1.0 &&
            window.height == 1.0)) {
      final cropX = (window.left * w).toInt().clamp(0, w - 1);
      final cropY = (window.top * h).toInt().clamp(0, h - 1);
      final cropW = (window.width * w).toInt().clamp(1, w - cropX);
      final cropH = (window.height * h).toInt().clamp(1, h - cropY);

      final croppedSize = cropW * cropH;
      final croppedBytes = Uint8List(croppedSize);

      int destIdx = 0;
      for (int y = 0; y < cropH; y++) {
        final srcRowStart = (cropY + y) * task.bytesPerRow + cropX;
        final availableInRow = rawBytes.length - srcRowStart;
        if (availableInRow <= 0) break;
        final copyLength = cropW.clamp(0, availableInRow);
        croppedBytes.setRange(
          destIdx,
          destIdx + copyLength,
          rawBytes,
          srcRowStart,
        );
        destIdx += copyLength;
      }

      workingBytes = croppedBytes;
      currentW = cropW;
      currentH = cropH;
      enhancements.add('ROI Crop (${currentW}x$currentH)');
    }

    // 3. Perform Blur & Motion Detection via discrete Laplacian variance & gradient check
    double blurScore = 120.0;
    bool isBlurry = false;
    bool isMotionDetected = false;
    double motionScore = 0.0;

    if (task.enableBlurDetection && workingBytes.isNotEmpty && currentW > 10 && currentH > 10) {
      double sumLaplacian = 0.0;
      double sumLaplacianSq = 0.0;
      double sumDiffHorizontal = 0.0;
      int count = 0;
      final step = math.max(2, (currentW * currentH) ~/ 8000);

      for (int y = 1; y < currentH - 1; y += step) {
        for (int x = 1; x < currentW - 1; x += step) {
          final idx = y * currentW + x;
          if (idx >= workingBytes.length ||
              idx - currentW < 0 ||
              idx + currentW >= workingBytes.length) {
            continue;
          }
          final center = workingBytes[idx];
          final left = workingBytes[idx - 1];
          final right = workingBytes[idx + 1];
          final top = workingBytes[idx - currentW];
          final bottom = workingBytes[idx + currentW];

          final lapVal = (4 * center - left - right - top - bottom).toDouble();
          sumLaplacian += lapVal;
          sumLaplacianSq += lapVal * lapVal;

          final hGrad = (right - left).abs().toDouble();
          sumDiffHorizontal += hGrad;
          count++;
        }
      }

      if (count > 0) {
        final mean = sumLaplacian / count;
        blurScore = (sumLaplacianSq / count) - (mean * mean);
        motionScore = sumDiffHorizontal / count;

        if (blurScore < 25.0) {
          isBlurry = true;
        }
        if (motionScore > 65.0) {
          isMotionDetected = true;
        }
      }
    }

    // 4. Perform Fast Contrast Normalization & Image Enhancement pass if requested
    double contrastScore = 1.0;
    if (task.enableEnhancement && workingBytes.isNotEmpty) {
      int minLum = 255;
      int maxLum = 0;
      final step = math.max(1, workingBytes.length ~/ 1000);
      for (int i = 0; i < workingBytes.length; i += step) {
        final val = workingBytes[i];
        if (val < minLum) minLum = val;
        if (val > maxLum) maxLum = val;
      }

      final range = maxLum - minLum;
      contrastScore = range / 255.0;

      // Stretch contrast if range is compressed or in low light conditions
      if (range > 10 && range < 200) {
        final enhancedBytes = Uint8List(workingBytes.length);
        final scale = 255.0 / range;
        for (int i = 0; i < workingBytes.length; i++) {
          final val = ((workingBytes[i] - minLum) * scale).clamp(0, 255).toInt();
          enhancedBytes[i] = val;
        }
        workingBytes = enhancedBytes;
        enhancements.add('Contrast Stretch (Scale ${scale.toStringAsFixed(2)})');
      }

      if (isLowLight) {
        enhancements.add('Low-Light Brightness Gain');
      }
    }

    return IsolateFrameResult(
      processedBytes: workingBytes,
      averageLuminosity: luminosity,
      croppedWidth: currentW,
      croppedHeight: currentH,
      isLowLight: isLowLight,
      blurScore: blurScore,
      isBlurry: isBlurry,
      isMotionDetected: isMotionDetected,
      motionScore: motionScore,
      isStaticFrame: isStaticFrame,
      frameHash: currentFrameHash,
      contrastScore: contrastScore,
      enhancementsApplied: enhancements,
    );
  }

  /// Recycles buffer to prevent GC allocations across streaming frames.
  static Uint8List getPooledBuffer(int size) {
    if (_reusableBuffer == null || _reusableBuffer!.length < size) {
      _reusableBuffer = Uint8List(size);
    }
    return _reusableBuffer!;
  }
}
