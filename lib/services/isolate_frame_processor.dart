import 'dart:typed_data';
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

  const IsolateFrameTaskData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    this.scanWindow,
    this.computeLuminosity = true,
  });
}

/// Structured response output returned from isolate frame processing.
class IsolateFrameResult {
  final Uint8List processedBytes;
  final double averageLuminosity;
  final int croppedWidth;
  final int croppedHeight;
  final bool isLowLight;

  const IsolateFrameResult({
    required this.processedBytes,
    required this.averageLuminosity,
    required this.croppedWidth,
    required this.croppedHeight,
    required this.isLowLight,
  });
}

/// Multithreaded background isolate worker for processing camera image frames,
/// performing sub-region ROI cropping, and calculating frame luminosity without UI stutter.
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

    // Calculate luminosity from Y (luma) plane
    double luminosity = 0.5;
    if (task.computeLuminosity && rawBytes.isNotEmpty) {
      int sum = 0;
      final sampleStep = (rawBytes.length ~/ 1000).clamp(1, 100);
      int sampleCount = 0;
      for (int i = 0; i < rawBytes.length && i < w * h; i += sampleStep) {
        sum += rawBytes[i];
        sampleCount++;
      }
      if (sampleCount > 0) {
        luminosity = (sum / sampleCount) / 255.0;
      }
    }

    final isLowLight = luminosity < 0.25;

    // ROI Sub-region cropping if scanWindow is defined and not full frame
    final window = task.scanWindow;
    if (window == null ||
        (window.left == 0.0 &&
            window.top == 0.0 &&
            window.width == 1.0 &&
            window.height == 1.0)) {
      return IsolateFrameResult(
        processedBytes: rawBytes,
        averageLuminosity: luminosity,
        croppedWidth: w,
        croppedHeight: h,
        isLowLight: isLowLight,
      );
    }

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

    return IsolateFrameResult(
      processedBytes: croppedBytes,
      averageLuminosity: luminosity,
      croppedWidth: cropW,
      croppedHeight: cropH,
      isLowLight: isLowLight,
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
