import 'package:flutter/material.dart';
import '../../core/models/scanner_mode.dart';
import '../../core/models/scanner_theme.dart';

/// Custom painter for camera viewfinder cutout, reticle corners, tap-to-focus ring,
/// detection highlight flash, and animated laser beam.
class ScannerOverlayPainter extends CustomPainter {
  /// Active scanning mode.
  final ScanMode scanMode;

  /// Animated progress value from 0.0 to 1.0.
  final double animationValue;

  /// Accent highlight color.
  final Color accentColor;

  /// Optional custom UI design theme configuration.
  final ScannerUiTheme? theme;

  /// User tap-to-focus point coordinates relative to overlay viewport.
  final Offset? focusPoint;

  /// Whether a valid barcode or document frame was detected in current frame pass.
  final bool isDetected;

  /// Detected target bounding box rectangle relative to screen coordinates.
  final Rect? detectedBoundingBox;

  /// Custom explicit scan rectangle area cutout.
  final Rect? customScanArea;

  /// List of bounding boxes for multiple detected codes.
  final List<Rect>? multiBoundingBoxes;

  /// Constructs a new [ScannerOverlayPainter].
  ScannerOverlayPainter({
    required this.scanMode,
    required this.animationValue,
    this.accentColor = const Color(0xFF00E5FF),
    this.theme,
    this.focusPoint,
    this.isDetected = false,
    this.detectedBoundingBox,
    this.customScanArea,
    this.multiBoundingBoxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveOverlayColor =
        theme?.overlayMaskColor ?? Colors.black.withValues(alpha: 0.65);
    final backgroundPaint = Paint()
      ..color = effectiveOverlayColor
      ..style = PaintingStyle.fill;

    final width = size.width;
    final height = size.height;

    late Rect scanRect;
    if (customScanArea != null) {
      scanRect = customScanArea!;
    } else {
      final targetRatio = scanMode.targetAspectRatio;
      double calcWidth = width * 0.85;
      double calcHeight = calcWidth / targetRatio;

      if (calcHeight > height * 0.6) {
        calcHeight = height * 0.6;
        calcWidth = calcHeight * targetRatio;
      }

      final calcLeft = (width - calcWidth) / 2;
      final calcTop = (height - calcHeight) / 2;
      scanRect = Rect.fromLTWH(calcLeft, calcTop, calcWidth, calcHeight);
    }

    final double rectLeft = scanRect.left;
    final double rectTop = scanRect.top;
    final double rectWidth = scanRect.width;
    final double rectHeight = scanRect.height;

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, width, height));

    final cornerRadius = theme?.reticleCornerRadius ?? 16.0;
    final cutoutPath = Path();
    if (scanMode == ScanMode.face) {
      cutoutPath.addOval(scanRect);
    } else {
      cutoutPath.addRRect(
        RRect.fromRectAndRadius(scanRect, Radius.circular(cornerRadius)),
      );
    }

    final path = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );
    canvas.drawPath(path, backgroundPaint);

    final effectiveBorderColor = isDetected
        ? const Color(0xFF00E676)
        : (theme?.reticleBorderColor ??
            (theme?.accentColor ?? accentColor).withValues(alpha: 0.85));
    final borderPaint = Paint()
      ..color = effectiveBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDetected ? 3.5 : (theme?.reticleBorderWidth ?? 2.5);

    if (scanMode == ScanMode.face) {
      canvas.drawOval(scanRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(scanRect, Radius.circular(cornerRadius)),
        borderPaint,
      );
    }

    if (scanMode != ScanMode.face) {
      final effectiveCornerColor = isDetected
          ? const Color(0xFF00E676)
          : (theme?.reticleCornerColor ?? theme?.accentColor ?? accentColor);
      final cornerPaint = Paint()
        ..color = effectiveCornerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = theme?.reticleCornerWidth ?? 4.5
        ..strokeCap = StrokeCap.round;

      final cornerLen = theme?.reticleCornerLength ?? 28.0;

      canvas.drawLine(
        Offset(rectLeft, rectTop + cornerLen),
        Offset(rectLeft, rectTop),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rectLeft, rectTop),
        Offset(rectLeft + cornerLen, rectTop),
        cornerPaint,
      );

      canvas.drawLine(
        Offset(rectLeft + rectWidth - cornerLen, rectTop),
        Offset(rectLeft + rectWidth, rectTop),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rectLeft + rectWidth, rectTop),
        Offset(rectLeft + rectWidth, rectTop + cornerLen),
        cornerPaint,
      );

      canvas.drawLine(
        Offset(rectLeft, rectTop + rectHeight - cornerLen),
        Offset(rectLeft, rectTop + rectHeight),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rectLeft, rectTop + rectHeight),
        Offset(rectLeft + cornerLen, rectTop + rectHeight),
        cornerPaint,
      );

      canvas.drawLine(
        Offset(rectLeft + rectWidth - cornerLen, rectTop + rectHeight),
        Offset(rectLeft + rectWidth, rectTop + rectHeight),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rectLeft + rectWidth, rectTop + rectHeight - cornerLen),
        Offset(rectLeft + rectWidth, rectTop + rectHeight),
        cornerPaint,
      );
    }

    // Render Laser Scanline with Gradient Glow
    if (theme?.showLaserBeam ?? true) {
      final effectiveLaserColor = isDetected
          ? const Color(0xFF00E676)
          : (theme?.laserBeamColor ?? theme?.accentColor ?? accentColor);
      final beamY = rectTop + (rectHeight * animationValue);

      final glowRect = Rect.fromLTWH(
        rectLeft + 8,
        beamY - 12,
        rectWidth - 16,
        24,
      );
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            effectiveLaserColor.withValues(alpha: 0.0),
            effectiveLaserColor.withValues(alpha: 0.25),
            effectiveLaserColor.withValues(alpha: 0.0),
          ],
        ).createShader(glowRect);
      canvas.drawRect(glowRect, glowPaint);

      final beamPaint = Paint()
        ..color = effectiveLaserColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(rectLeft + 8, beamY),
        Offset(rectLeft + rectWidth - 8, beamY),
        beamPaint,
      );
    }

    // Render Detected Bounding Box Highlight
    if (detectedBoundingBox != null) {
      final boxPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(detectedBoundingBox!, const Radius.circular(8)),
        boxPaint,
      );
    }

    // Render Tap-to-Focus Ring with ripple effect
    if (focusPoint != null) {
      final rippleRadius = 22.0 + (animationValue * 6.0);
      final focusPaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(focusPoint!, rippleRadius, focusPaint);
      canvas.drawLine(
        Offset(focusPoint!.dx - 8, focusPoint!.dy),
        Offset(focusPoint!.dx + 8, focusPoint!.dy),
        focusPaint,
      );
      canvas.drawLine(
        Offset(focusPoint!.dx, focusPoint!.dy - 8),
        Offset(focusPoint!.dx, focusPoint!.dy + 8),
        focusPaint,
      );
    }

    if (scanMode == ScanMode.passport) {
      final mrzHeight = rectHeight * 0.35;
      final mrzRect = Rect.fromLTWH(
        rectLeft + 12,
        rectTop + rectHeight - mrzHeight - 12,
        rectWidth - 24,
        mrzHeight,
      );
      final mrzPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(mrzRect, const Radius.circular(8)),
        mrzPaint,
      );
    } else if (scanMode == ScanMode.face) {
      final guidePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final eyeY = rectTop + rectHeight * 0.38;
      canvas.drawCircle(
        Offset(rectLeft + rectWidth * 0.32, eyeY),
        14,
        guidePaint,
      );
      canvas.drawCircle(
        Offset(rectLeft + rectWidth * 0.68, eyeY),
        14,
        guidePaint,
      );
    } else if (scanMode == ScanMode.document) {
      final docPaint = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final margin = 16.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rectLeft + margin,
            rectTop + margin,
            rectWidth - (margin * 2),
            rectHeight - (margin * 2),
          ),
          const Radius.circular(12),
        ),
        docPaint,
      );
    } else if (scanMode == ScanMode.multiCode) {
      final multiPaint = Paint()
        ..color = Colors.lightGreenAccent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(
        Offset(rectLeft + rectWidth * 0.3, rectTop + rectHeight * 0.35),
        24,
        multiPaint,
      );
      canvas.drawCircle(
        Offset(rectLeft + rectWidth * 0.7, rectTop + rectHeight * 0.65),
        24,
        multiPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.scanMode != scanMode ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.theme != theme ||
        oldDelegate.focusPoint != focusPoint ||
        oldDelegate.isDetected != isDetected ||
        oldDelegate.detectedBoundingBox != detectedBoundingBox;
  }
}

