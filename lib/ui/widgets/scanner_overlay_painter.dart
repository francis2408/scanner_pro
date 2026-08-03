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

  /// Constructs a new [ScannerOverlayPainter].
  ScannerOverlayPainter({
    required this.scanMode,
    required this.animationValue,
    this.accentColor = const Color(0xFF00E5FF),
    this.theme,
    this.focusPoint,
    this.isDetected = false,
    this.detectedBoundingBox,
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

    final targetRatio = scanMode.targetAspectRatio;
    double rectWidth = width * 0.85;
    double rectHeight = rectWidth / targetRatio;

    if (rectHeight > height * 0.6) {
      rectHeight = height * 0.6;
      rectWidth = rectHeight * targetRatio;
    }

    final rectLeft = (width - rectWidth) / 2;
    final rectTop = (height - rectHeight) / 2;
    final scanRect = Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight);

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

