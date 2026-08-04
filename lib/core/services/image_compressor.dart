import 'dart:typed_data';

/// Compression quality preset levels for image output.
enum CompressionPreset {
  /// Minimal compression, highest quality (~95% retention).
  ultraHigh,

  /// Standard high quality compression (~85% retention).
  high,

  /// Balanced quality vs size compression (~70% retention).
  medium,

  /// Aggressive compression for minimal file sizes (~50% retention).
  low,

  /// Maximum compression with visible quality loss (~30% retention).
  thumbnail,
}

/// Extension providing numeric quality factor for each [CompressionPreset].
extension CompressionPresetExtension on CompressionPreset {
  /// Quality factor from 0.0 to 1.0 for this preset.
  double get qualityFactor {
    switch (this) {
      case CompressionPreset.ultraHigh:
        return 0.95;
      case CompressionPreset.high:
        return 0.85;
      case CompressionPreset.medium:
        return 0.70;
      case CompressionPreset.low:
        return 0.50;
      case CompressionPreset.thumbnail:
        return 0.30;
    }
  }

  /// Human-readable label for this compression preset.
  String get label {
    switch (this) {
      case CompressionPreset.ultraHigh:
        return 'Ultra High (95%)';
      case CompressionPreset.high:
        return 'High (85%)';
      case CompressionPreset.medium:
        return 'Medium (70%)';
      case CompressionPreset.low:
        return 'Low (50%)';
      case CompressionPreset.thumbnail:
        return 'Thumbnail (30%)';
    }
  }
}

/// Result of an image compression operation.
class CompressionResult {
  /// Compressed image byte buffer.
  final Uint8List compressedBytes;

  /// Original byte size before compression.
  final int originalSize;

  /// Final byte size after compression.
  final int compressedSize;

  /// Compression ratio achieved (0.0 to 1.0, lower = more compressed).
  final double compressionRatio;

  /// Quality factor used during compression (0.0 to 1.0).
  final double qualityUsed;

  /// Duration elapsed during compression.
  final Duration elapsed;

  const CompressionResult({
    required this.compressedBytes,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
    required this.qualityUsed,
    required this.elapsed,
  });

  /// Size reduction percentage achieved (e.g. 45.2 means 45.2% smaller).
  double get reductionPercent => (1.0 - compressionRatio) * 100.0;

  /// Human-readable compression summary string.
  String get summary =>
      'Compressed ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} '
      '(${reductionPercent.toStringAsFixed(1)}% reduction, quality: ${(qualityUsed * 100).toStringAsFixed(0)}%)';

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  String toString() => 'CompressionResult($summary)';
}

/// Enterprise image compression engine supporting quality-based compression,
/// downsampling, batch processing, and memory-efficient streaming for large buffers.
class ImageCompressor {
  /// Compresses raw image bytes using quality-based quantization and stride downsampling.
  ///
  /// [bytes] — Raw image byte buffer (grayscale or RGBA pixel data).
  /// [quality] — Quality factor from 0.0 (max compression) to 1.0 (no compression).
  /// [preserveAlpha] — If true, preserves every 4th byte (alpha channel) unmodified.
  static CompressionResult compress(
    Uint8List bytes, {
    double quality = 0.85,
    bool preserveAlpha = false,
  }) {
    final stopwatch = Stopwatch()..start();
    final clampedQuality = quality.clamp(0.05, 1.0);

    if (bytes.isEmpty || clampedQuality >= 0.99) {
      stopwatch.stop();
      return CompressionResult(
        compressedBytes: bytes,
        originalSize: bytes.length,
        compressedSize: bytes.length,
        compressionRatio: 1.0,
        qualityUsed: clampedQuality,
        elapsed: stopwatch.elapsed,
      );
    }

    // Step 1: Quantization — reduce color depth based on quality
    final quantizationBits = _qualityToQuantizationBits(clampedQuality);
    final quantized = _quantizeBytes(bytes, quantizationBits, preserveAlpha);

    // Step 2: Stride downsampling — skip pixels based on quality
    final step = _qualityToStride(clampedQuality);
    final Uint8List compressed;
    if (step <= 1) {
      compressed = quantized;
    } else {
      final result = <int>[];
      for (int i = 0; i < quantized.length; i += step) {
        result.add(quantized[i]);
      }
      compressed = Uint8List.fromList(result);
    }

    // Step 3: Run-length encoding for repeated byte sequences
    final rleCompressed = _applyRle(compressed, clampedQuality);

    stopwatch.stop();
    return CompressionResult(
      compressedBytes: rleCompressed,
      originalSize: bytes.length,
      compressedSize: rleCompressed.length,
      compressionRatio:
          bytes.isNotEmpty ? rleCompressed.length / bytes.length : 1.0,
      qualityUsed: clampedQuality,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Compresses raw image bytes using a named [CompressionPreset].
  static CompressionResult compressWithPreset(
    Uint8List bytes,
    CompressionPreset preset,
  ) {
    return compress(bytes, quality: preset.qualityFactor);
  }

  /// Batch compresses multiple image byte buffers with shared quality settings.
  ///
  /// Returns a list of [CompressionResult] in the same order as input buffers.
  static List<CompressionResult> batchCompress(
    List<Uint8List> buffers, {
    double quality = 0.85,
  }) {
    return buffers.map((buf) => compress(buf, quality: quality)).toList();
  }

  /// Estimates compressed output size without performing actual compression.
  ///
  /// Useful for UI progress indicators and storage planning.
  static int estimateCompressedSize(int originalSize, {double quality = 0.85}) {
    final q = quality.clamp(0.05, 1.0);
    final stride = _qualityToStride(q);
    final quantizationReduction = 1.0 - ((1.0 - q) * 0.15);
    final strideReduction = stride > 1 ? (1.0 / stride) : 1.0;
    return (originalSize * quantizationReduction * strideReduction).round();
  }

  /// Downsamples image dimensions by the given [factor] (e.g. 2 = half resolution).
  ///
  /// [width] and [height] define original image dimensions.
  /// [bytesPerPixel] is typically 1 (grayscale) or 4 (RGBA).
  static Uint8List downsample(
    Uint8List bytes, {
    required int width,
    required int height,
    int factor = 2,
    int bytesPerPixel = 1,
  }) {
    if (factor <= 1 || bytes.isEmpty) return bytes;
    final clampedFactor = factor.clamp(1, 8);
    final newWidth = (width / clampedFactor).ceil();
    final newHeight = (height / clampedFactor).ceil();
    final result = Uint8List(newWidth * newHeight * bytesPerPixel);

    int outIndex = 0;
    for (int y = 0; y < height && outIndex < result.length; y += clampedFactor) {
      for (int x = 0; x < width && outIndex < result.length; x += clampedFactor) {
        final srcIndex = (y * width + x) * bytesPerPixel;
        for (int c = 0; c < bytesPerPixel && outIndex < result.length; c++) {
          if (srcIndex + c < bytes.length) {
            result[outIndex++] = bytes[srcIndex + c];
          }
        }
      }
    }

    return Uint8List.view(result.buffer, 0, outIndex);
  }

  // --- Internal Helpers ---

  static int _qualityToQuantizationBits(double quality) {
    // Higher quality = more bits preserved (8 = lossless, 4 = heavy loss)
    return (4 + (quality * 4)).round().clamp(4, 8);
  }

  static int _qualityToStride(double quality) {
    if (quality >= 0.90) return 1;
    if (quality >= 0.70) return 2;
    if (quality >= 0.50) return 3;
    if (quality >= 0.30) return 4;
    return 6;
  }

  static Uint8List _quantizeBytes(
      Uint8List bytes, int bits, bool preserveAlpha) {
    if (bits >= 8) return bytes;
    final mask = ((1 << bits) - 1) << (8 - bits);
    final result = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i++) {
      if (preserveAlpha && (i % 4 == 3)) {
        result[i] = bytes[i];
      } else {
        result[i] = bytes[i] & mask;
      }
    }
    return result;
  }

  static Uint8List _applyRle(Uint8List bytes, double quality) {
    // Only apply RLE for medium/low quality to avoid overhead on high-quality data
    if (quality > 0.80 || bytes.length < 64) return bytes;

    final result = <int>[];
    int i = 0;
    while (i < bytes.length) {
      final val = bytes[i];
      int count = 1;
      while (i + count < bytes.length &&
          bytes[i + count] == val &&
          count < 255) {
        count++;
      }
      if (count >= 3) {
        // RLE marker: 0xFF, count, value
        result.addAll([0xFE, count, val]);
      } else {
        for (int j = 0; j < count; j++) {
          result.add(val);
        }
      }
      i += count;
    }

    // Only use RLE result if it's actually smaller
    if (result.length < bytes.length) {
      return Uint8List.fromList(result);
    }
    return bytes;
  }
}
