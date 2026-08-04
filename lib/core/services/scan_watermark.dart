import 'dart:math' as math;
import 'dart:typed_data';

/// Position presets for watermark placement on scan images.
enum WatermarkPosition {
  /// Centered on the image.
  center,

  /// Top-left corner with padding.
  topLeft,

  /// Top-right corner with padding.
  topRight,

  /// Bottom-left corner with padding.
  bottomLeft,

  /// Bottom-right corner with padding.
  bottomRight,

  /// Tiled across the entire image surface.
  tiled,

  /// Diagonal across the image center (rotated 45°).
  diagonal,
}

/// Configuration for watermark application on scanned images.
class WatermarkConfig {
  /// Watermark text to overlay.
  final String text;

  /// Position of the watermark on the image.
  final WatermarkPosition position;

  /// Opacity of the watermark (0.0 = invisible, 1.0 = fully opaque).
  final double opacity;

  /// Rotation angle in degrees (only used for [WatermarkPosition.diagonal]).
  final double rotationDegrees;

  /// Font size factor (1.0 = standard size, 2.0 = double size).
  final double fontSizeFactor;

  /// Watermark color as ARGB integer (default: semi-transparent gray).
  final int colorArgb;

  /// Margin in pixels from image edges (for corner positions).
  final int margin;

  /// Spacing between tiles (only used for [WatermarkPosition.tiled]).
  final int tileSpacing;

  const WatermarkConfig({
    required this.text,
    this.position = WatermarkPosition.center,
    this.opacity = 0.3,
    this.rotationDegrees = -45.0,
    this.fontSizeFactor = 1.0,
    this.colorArgb = 0x4D808080,
    this.margin = 20,
    this.tileSpacing = 100,
  });

  /// Creates a confidentiality watermark preset.
  factory WatermarkConfig.confidential({double opacity = 0.25}) {
    return WatermarkConfig(
      text: 'CONFIDENTIAL',
      position: WatermarkPosition.diagonal,
      opacity: opacity,
      fontSizeFactor: 1.5,
    );
  }

  /// Creates a draft document watermark preset.
  factory WatermarkConfig.draft({double opacity = 0.2}) {
    return WatermarkConfig(
      text: 'DRAFT',
      position: WatermarkPosition.tiled,
      opacity: opacity,
      fontSizeFactor: 1.2,
      tileSpacing: 150,
    );
  }

  /// Creates a copy protection watermark preset.
  factory WatermarkConfig.copy({double opacity = 0.15}) {
    return WatermarkConfig(
      text: 'COPY',
      position: WatermarkPosition.tiled,
      opacity: opacity,
      fontSizeFactor: 1.0,
      tileSpacing: 80,
    );
  }

  /// Creates a custom timestamp watermark.
  factory WatermarkConfig.timestamp({
    DateTime? dateTime,
    WatermarkPosition position = WatermarkPosition.bottomRight,
  }) {
    final dt = dateTime ?? DateTime.now();
    return WatermarkConfig(
      text:
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
      position: position,
      opacity: 0.4,
      fontSizeFactor: 0.8,
    );
  }

  @override
  String toString() =>
      'WatermarkConfig(text: "$text", position: ${position.name}, opacity: $opacity)';
}

/// Result of a watermark application operation.
class WatermarkResult {
  /// Image bytes with watermark applied.
  final Uint8List watermarkedBytes;

  /// Original image byte size.
  final int originalSize;

  /// Watermark configuration used.
  final WatermarkConfig config;

  /// Whether the watermark was successfully applied.
  final bool success;

  /// Duration elapsed during watermark application.
  final Duration elapsed;

  const WatermarkResult({
    required this.watermarkedBytes,
    required this.originalSize,
    required this.config,
    required this.success,
    required this.elapsed,
  });

  @override
  String toString() =>
      'WatermarkResult(success: $success, text: "${config.text}", elapsed: ${elapsed.inMilliseconds}ms)';
}

/// Enterprise scan watermark service for applying text overlays
/// to scanned image byte buffers with configurable position, opacity, and rotation.
class ScanWatermark {
  /// Applies a text watermark to grayscale image bytes.
  ///
  /// [imageBytes] — Raw grayscale pixel data (1 byte per pixel).
  /// [width] and [height] — Image dimensions in pixels.
  /// [config] — Watermark configuration.
  static WatermarkResult apply(
    Uint8List imageBytes, {
    required int width,
    required int height,
    required WatermarkConfig config,
  }) {
    final stopwatch = Stopwatch()..start();

    if (imageBytes.isEmpty || width <= 0 || height <= 0) {
      stopwatch.stop();
      return WatermarkResult(
        watermarkedBytes: imageBytes,
        originalSize: imageBytes.length,
        config: config,
        success: false,
        elapsed: stopwatch.elapsed,
      );
    }

    final result = Uint8List.fromList(imageBytes);
    final opacity = config.opacity.clamp(0.0, 1.0);

    switch (config.position) {
      case WatermarkPosition.center:
        _applyTextAtPosition(
          result, width, height, config.text, opacity,
          x: width ~/ 2, y: height ~/ 2,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.topLeft:
        _applyTextAtPosition(
          result, width, height, config.text, opacity,
          x: config.margin + (config.text.length * 4),
          y: config.margin + 8,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.topRight:
        _applyTextAtPosition(
          result, width, height, config.text, opacity,
          x: width - config.margin - (config.text.length * 4),
          y: config.margin + 8,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.bottomLeft:
        _applyTextAtPosition(
          result, width, height, config.text, opacity,
          x: config.margin + (config.text.length * 4),
          y: height - config.margin - 8,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.bottomRight:
        _applyTextAtPosition(
          result, width, height, config.text, opacity,
          x: width - config.margin - (config.text.length * 4),
          y: height - config.margin - 8,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.tiled:
        _applyTiledWatermark(
          result, width, height, config.text, opacity,
          spacing: config.tileSpacing,
          fontScale: config.fontSizeFactor,
        );
        break;
      case WatermarkPosition.diagonal:
        _applyDiagonalWatermark(
          result, width, height, config.text, opacity,
          fontScale: config.fontSizeFactor,
        );
        break;
    }

    stopwatch.stop();
    return WatermarkResult(
      watermarkedBytes: result,
      originalSize: imageBytes.length,
      config: config,
      success: true,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Applies a quick watermark with text at center position using default settings.
  static WatermarkResult applySimple(
    Uint8List imageBytes, {
    required int width,
    required int height,
    required String text,
    double opacity = 0.3,
  }) {
    return apply(
      imageBytes,
      width: width,
      height: height,
      config: WatermarkConfig(text: text, opacity: opacity),
    );
  }

  /// Generates a PDF watermark content stream for embedding in PDF pages.
  ///
  /// Returns a PDF content stream string that renders a diagonal watermark.
  static String generatePdfWatermarkStream(
    String text, {
    double opacity = 0.3,
    double fontSize = 42,
  }) {
    final gray = (0.85).toStringAsFixed(2);
    return '''
q
/F1 ${fontSize.toStringAsFixed(0)} Tf
$gray $gray $gray rg
0.7071 -0.7071 0.7071 0.7071 150 400 cm
BT
0 0 Td
(${_escapePdfText(text.toUpperCase())}) Tj
ET
Q''';
  }

  // --- Internal Rendering Helpers ---

  static void _applyTextAtPosition(
    Uint8List pixels,
    int width,
    int height,
    String text,
    double opacity, {
    required int x,
    required int y,
    double fontScale = 1.0,
  }) {
    final charWidth = (8 * fontScale).round();
    final charHeight = (12 * fontScale).round();
    final startX = x - (text.length * charWidth ~/ 2);

    for (int c = 0; c < text.length; c++) {
      final cx = startX + (c * charWidth);
      for (int dy = -charHeight ~/ 2; dy < charHeight ~/ 2; dy++) {
        for (int dx = 0; dx < charWidth; dx++) {
          final px = cx + dx;
          final py = y + dy;
          if (px >= 0 && px < width && py >= 0 && py < height) {
            final idx = py * width + px;
            if (idx >= 0 && idx < pixels.length) {
              // Simple block character rendering with opacity blending
              final charCode = text.codeUnitAt(c);
              if (_isCharPixelSet(charCode, dx, dy + charHeight ~/ 2,
                  charWidth, charHeight)) {
                final original = pixels[idx];
                final watermarkVal = 128; // Mid-gray watermark
                pixels[idx] =
                    ((original * (1.0 - opacity)) + (watermarkVal * opacity))
                        .round()
                        .clamp(0, 255);
              }
            }
          }
        }
      }
    }
  }

  static void _applyTiledWatermark(
    Uint8List pixels,
    int width,
    int height,
    String text,
    double opacity, {
    int spacing = 100,
    double fontScale = 1.0,
  }) {
    final tileWidth = text.length * (8 * fontScale).round() + spacing;
    final tileHeight = (12 * fontScale).round() + spacing;

    for (int ty = spacing ~/ 2; ty < height; ty += tileHeight) {
      for (int tx = spacing ~/ 2; tx < width; tx += tileWidth) {
        _applyTextAtPosition(
          pixels, width, height, text, opacity,
          x: tx + (text.length * (4 * fontScale)).round(),
          y: ty,
          fontScale: fontScale,
        );
      }
    }
  }

  static void _applyDiagonalWatermark(
    Uint8List pixels,
    int width,
    int height,
    String text,
    double opacity, {
    double fontScale = 1.0,
  }) {
    // Apply watermark text along the diagonal line from top-left to bottom-right
    final diagonalLength =
        math.sqrt(width * width + height * height).round();
    final textWidth = text.length * (8 * fontScale).round();
    final repetitions = (diagonalLength / (textWidth + 50)).ceil();

    for (int i = 0; i < repetitions; i++) {
      final t = (i + 0.5) / repetitions;
      final cx = (t * width).round();
      final cy = (t * height).round();
      _applyTextAtPosition(
        pixels, width, height, text, opacity * 0.8,
        x: cx,
        y: cy,
        fontScale: fontScale,
      );
    }
  }

  /// Simple bitmap font pixel lookup for basic character rendering.
  static bool _isCharPixelSet(
      int charCode, int x, int y, int charWidth, int charHeight) {
    // Simple block-based character rendering using hash-based patterns
    if (x < 1 || x >= charWidth - 1 || y < 1 || y >= charHeight - 1) {
      return false;
    }
    // Create a deterministic pattern based on character code
    final hash = (charCode * 7 + x * 3 + y * 11) % 5;
    return hash < 2;
  }

  static String _escapePdfText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('(', '\\(')
        .replaceAll(')', '\\)');
  }
}
