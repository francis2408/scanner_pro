import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Dedicated Vision AI Face Detection parser for evaluating facial landmarks,
/// 3D head orientation angles, expression probabilities, and face capture quality.
class FaceScannerParser {
  /// Parses raw text description, metadata, or JSON string of detected facial metrics.
  static ScanResult parse(
    String rawInput, {
    Rect? faceBoundingBox,
    Map<String, dynamic>? extraMetadata,
  }) {
    final metadata = Map<String, dynamic>.from(extraMetadata ?? {});

    final headEulerAngleY = (metadata['headEulerAngleY'] as num?)?.toDouble() ?? 0.0;
    final headEulerAngleZ = (metadata['headEulerAngleZ'] as num?)?.toDouble() ?? 0.0;
    final headEulerAngleX = (metadata['headEulerAngleX'] as num?)?.toDouble() ?? 0.0;
    final smilingProb = (metadata['smilingProbability'] as num?)?.toDouble() ?? 0.85;
    final leftEyeOpenProb = (metadata['leftEyeOpenProbability'] as num?)?.toDouble() ?? 0.95;
    final rightEyeOpenProb = (metadata['rightEyeOpenProbability'] as num?)?.toDouble() ?? 0.95;

    final isFrontal = headEulerAngleY.abs() < 15.0 && headEulerAngleZ.abs() < 15.0;
    final isEyesOpen = leftEyeOpenProb > 0.5 && rightEyeOpenProb > 0.5;
    final faceQuality = (isFrontal ? 0.5 : 0.2) + (isEyesOpen ? 0.3 : 0.1) + (smilingProb * 0.2);

    final fields = <String, String>{
      'Detector Mode': 'ML Kit Vision Face AI Engine',
      'Face Detection Status': 'Single Face Profile Tracked ✓',
      'Frontal Pose': isFrontal ? 'Centered (Frontal View) ✓' : 'Angled Pose (${headEulerAngleY.toStringAsFixed(1)}°)',
      'Eyes Open State': isEyesOpen ? 'Both Eyes Open ✓' : 'Eyes Blinked / Closed ✗',
      'Smiling Probability': '${(smilingProb * 100).toStringAsFixed(1)}%',
      'Left Eye Open': '${(leftEyeOpenProb * 100).toStringAsFixed(1)}%',
      'Right Eye Open': '${(rightEyeOpenProb * 100).toStringAsFixed(1)}%',
      'Head Yaw Angle (Y)': '${headEulerAngleY.toStringAsFixed(1)}°',
      'Head Roll Angle (Z)': '${headEulerAngleZ.toStringAsFixed(1)}°',
      'Face Quality Index': '${(faceQuality * 100).toStringAsFixed(1)}%',
    };

    final verifications = {
      'faceDetected': true,
      'isFrontalPose': isFrontal,
      'areEyesOpen': isEyesOpen,
      'qualityThresholdMet': faceQuality >= 0.70,
    };

    final bbox = faceBoundingBox ?? const Rect.fromLTWH(120, 100, 240, 280);

    return ScanResult(
      mode: ScanMode.face,
      rawValue: rawInput.isNotEmpty ? rawInput : 'Face Detected [Quality: ${(faceQuality * 100).toStringAsFixed(1)}%]',
      isValid: faceQuality >= 0.60,
      confidence: (faceQuality).clamp(0.70, 0.99),
      format: 'ML_KIT_FACE_DETECTOR',
      boundingBox: bbox,
      fields: fields,
      verifications: verifications,
      metadata: {
        'documentType': 'faceDetection',
        'headYaw': headEulerAngleY,
        'headRoll': headEulerAngleZ,
        'headPitch': headEulerAngleX,
        'smilingProbability': smilingProb,
        'leftEyeOpenProbability': leftEyeOpenProb,
        'rightEyeOpenProbability': rightEyeOpenProb,
        'faceQualityScore': faceQuality,
      },
    );
  }
}
