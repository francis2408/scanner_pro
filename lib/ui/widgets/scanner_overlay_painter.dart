import 'package:flutter/material.dart';
import '../../core/models/scanner_mode.dart';

class ScannerOverlayPainter extends CustomPainter {
  final ScanMode scanMode;
  final double animationValue;
  final Color accentColor;

  ScannerOverlayPainter({
    required this.scanMode,
    required this.animationValue,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
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

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height));

    final cutoutPath = Path();
    if (scanMode == ScanMode.face) {
      cutoutPath.addOval(scanRect);
    } else {
      cutoutPath.addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)));
    }

    final path = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(path, backgroundPaint);

    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (scanMode == ScanMode.face) {
      canvas.drawOval(scanRect, borderPaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16)), borderPaint);
    }

    if (scanMode != ScanMode.face) {
      final cornerPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      const cornerLen = 28.0;

      canvas.drawLine(Offset(rectLeft, rectTop + cornerLen), Offset(rectLeft, rectTop), cornerPaint);
      canvas.drawLine(Offset(rectLeft, rectTop), Offset(rectLeft + cornerLen, rectTop), cornerPaint);

      canvas.drawLine(Offset(rectLeft + rectWidth - cornerLen, rectTop), Offset(rectLeft + rectWidth, rectTop), cornerPaint);
      canvas.drawLine(Offset(rectLeft + rectWidth, rectTop), Offset(rectLeft + rectWidth, rectTop + cornerLen), cornerPaint);

      canvas.drawLine(Offset(rectLeft, rectTop + rectHeight - cornerLen), Offset(rectLeft, rectTop + rectHeight), cornerPaint);
      canvas.drawLine(Offset(rectLeft, rectTop + rectHeight), Offset(rectLeft + cornerLen, rectTop + rectHeight), cornerPaint);

      canvas.drawLine(Offset(rectLeft + rectWidth - cornerLen, rectTop + rectHeight), Offset(rectLeft + rectWidth, rectTop + rectHeight), cornerPaint);
      canvas.drawLine(Offset(rectLeft + rectWidth, rectTop + rectHeight - cornerLen), Offset(rectLeft + rectWidth, rectTop + rectHeight), cornerPaint);
    }

    final beamY = rectTop + (rectHeight * animationValue);
    final beamPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(rectLeft + 8, beamY), Offset(rectLeft + rectWidth - 8, beamY), beamPaint);

    if (scanMode == ScanMode.passport) {
      final mrzHeight = rectHeight * 0.35;
      final mrzRect = Rect.fromLTWH(rectLeft + 12, rectTop + rectHeight - mrzHeight - 12, rectWidth - 24, mrzHeight);
      final mrzPaint = Paint()
        ..color = Colors.amber.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(RRect.fromRectAndRadius(mrzRect, const Radius.circular(8)), mrzPaint);
    } else if (scanMode == ScanMode.face) {
      final guidePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final eyeY = rectTop + rectHeight * 0.38;
      canvas.drawCircle(Offset(rectLeft + rectWidth * 0.32, eyeY), 14, guidePaint);
      canvas.drawCircle(Offset(rectLeft + rectWidth * 0.68, eyeY), 14, guidePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.scanMode != scanMode ||
        oldDelegate.accentColor != accentColor;
  }
}
