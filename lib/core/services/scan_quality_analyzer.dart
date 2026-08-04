import 'dart:math' as math;
import 'dart:typed_data';

/// Scan quality grade based on overall image analysis.
enum QualityGrade {
  /// Excellent quality — sharp, well-lit, properly aligned.
  excellent,

  /// Good quality — minor issues that don't affect scanning.
  good,

  /// Acceptable quality — may affect recognition accuracy.
  acceptable,

  /// Poor quality — likely to cause scan failures.
  poor,

  /// Unusable — image is too degraded for reliable scanning.
  unusable,
}

/// Extension providing metadata for [QualityGrade].
extension QualityGradeExtension on QualityGrade {
  /// Letter grade (A, B, C, D, F).
  String get letterGrade {
    switch (this) {
      case QualityGrade.excellent:
        return 'A';
      case QualityGrade.good:
        return 'B';
      case QualityGrade.acceptable:
        return 'C';
      case QualityGrade.poor:
        return 'D';
      case QualityGrade.unusable:
        return 'F';
    }
  }

  /// Human-readable label.
  String get label {
    switch (this) {
      case QualityGrade.excellent:
        return 'Excellent';
      case QualityGrade.good:
        return 'Good';
      case QualityGrade.acceptable:
        return 'Acceptable';
      case QualityGrade.poor:
        return 'Poor';
      case QualityGrade.unusable:
        return 'Unusable';
    }
  }

  /// Whether this grade is adequate for reliable scanning.
  bool get isAdequate =>
      this == QualityGrade.excellent ||
      this == QualityGrade.good ||
      this == QualityGrade.acceptable;
}

/// Blur severity level detected in a scanned image.
enum BlurSeverity {
  /// Image is sharp with clear edges.
  sharp,

  /// Slight blur — generally still scannable.
  mild,

  /// Moderate blur — may affect OCR accuracy.
  moderate,

  /// Heavy blur — likely to cause detection failures.
  heavy,
}

/// Light condition assessment for scan environment.
enum LightCondition {
  /// Ambient lighting is too dark for reliable scanning.
  tooLow,

  /// Low but potentially usable lighting.
  low,

  /// Normal indoor or outdoor lighting.
  normal,

  /// Bright, well-lit environment.
  bright,

  /// Overexposed — too much light causing glare/washout.
  overexposed,
}

/// Comprehensive scan quality analysis report.
class ScanQualityReport {
  /// Overall quality grade.
  final QualityGrade grade;

  /// Overall quality score (0.0 to 1.0).
  final double overallScore;

  /// Blur analysis results.
  final BlurAnalysis blur;

  /// Light condition analysis results.
  final LightAnalysis light;

  /// Skew/tilt analysis results.
  final SkewAnalysis skew;

  /// Contrast analysis results.
  final ContrastAnalysis contrast;

  /// Human-readable recommendations for improving scan quality.
  final List<String> recommendations;

  /// Duration elapsed during analysis.
  final Duration analysisTime;

  const ScanQualityReport({
    required this.grade,
    required this.overallScore,
    required this.blur,
    required this.light,
    required this.skew,
    required this.contrast,
    required this.recommendations,
    required this.analysisTime,
  });

  /// Whether the scan quality is adequate for reliable scanning.
  bool get isAdequate => grade.isAdequate;

  /// Whether torch/flash is recommended based on light conditions.
  bool get torchRecommended =>
      light.condition == LightCondition.tooLow ||
      light.condition == LightCondition.low;

  factory ScanQualityReport.fromJson(Map<String, dynamic> json) {
    final gradeStr = json['grade'] as String? ?? 'A';
    final grade = QualityGrade.values.firstWhere(
      (g) => g.letterGrade == gradeStr,
      orElse: () => QualityGrade.excellent,
    );

    return ScanQualityReport(
      grade: grade,
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 1.0,
      blur: json['blur'] != null
          ? BlurAnalysis.fromJson(json['blur'] as Map<String, dynamic>)
          : const BlurAnalysis(
              severity: BlurSeverity.sharp,
              score: 0.0,
              laplacianVariance: 500.0,
            ),
      light: json['light'] != null
          ? LightAnalysis.fromJson(json['light'] as Map<String, dynamic>)
          : const LightAnalysis(
              condition: LightCondition.normal,
              averageLuminance: 0.5,
              estimatedLux: 500.0,
              torchRecommended: false,
            ),
      skew: json['skew'] != null
          ? SkewAnalysis.fromJson(json['skew'] as Map<String, dynamic>)
          : const SkewAnalysis(
              angleDegrees: 0.0,
              isAligned: true,
              correctionAngle: 0.0,
            ),
      contrast: json['contrast'] != null
          ? ContrastAnalysis.fromJson(json['contrast'] as Map<String, dynamic>)
          : const ContrastAnalysis(
              contrastRatio: 0.8,
              isAdequate: true,
              dynamicRange: 200,
            ),
      recommendations: (json['recommendations'] as List?)
              ?.map((r) => r.toString())
              .toList() ??
          const [],
      analysisTime: json['analysisTimeMs'] != null
          ? Duration(milliseconds: json['analysisTimeMs'] as int)
          : Duration.zero,
    );
  }

  Map<String, dynamic> toJson() => {
        'grade': grade.letterGrade,
        'overallScore': overallScore,
        'blur': blur.toJson(),
        'light': light.toJson(),
        'skew': skew.toJson(),
        'contrast': contrast.toJson(),
        'recommendations': recommendations,
        'analysisTimeMs': analysisTime.inMilliseconds,
      };

  @override
  String toString() =>
      'ScanQualityReport(grade: ${grade.letterGrade}, score: ${(overallScore * 100).toStringAsFixed(1)}%, '
      'blur: ${blur.severity.name}, light: ${light.condition.name})';
}

/// Blur detection analysis results.
class BlurAnalysis {
  /// Blur severity level.
  final BlurSeverity severity;

  /// Blur score (0.0 = perfectly sharp, 1.0 = completely blurred).
  final double score;

  /// Discrete Laplacian variance (higher = sharper).
  final double laplacianVariance;

  const BlurAnalysis({
    required this.severity,
    required this.score,
    required this.laplacianVariance,
  });

  /// Whether the image is sharp enough for reliable scanning.
  bool get isSharp =>
      severity == BlurSeverity.sharp || severity == BlurSeverity.mild;

  factory BlurAnalysis.fromJson(Map<String, dynamic> json) {
    final sevStr = json['severity'] as String? ?? 'sharp';
    final severity = BlurSeverity.values.firstWhere(
      (s) => s.name == sevStr,
      orElse: () => BlurSeverity.sharp,
    );

    return BlurAnalysis(
      severity: severity,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      laplacianVariance: (json['laplacianVariance'] as num?)?.toDouble() ?? 500.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'score': score,
        'laplacianVariance': laplacianVariance,
        'isSharp': isSharp,
      };
}

/// Light condition analysis results.
class LightAnalysis {
  /// Detected light condition.
  final LightCondition condition;

  /// Average luminance score (0.0 = pitch black, 1.0 = pure white).
  final double averageLuminance;

  /// Estimated lux level.
  final double estimatedLux;

  /// Whether torch/flash is recommended.
  final bool torchRecommended;

  const LightAnalysis({
    required this.condition,
    required this.averageLuminance,
    required this.estimatedLux,
    required this.torchRecommended,
  });

  factory LightAnalysis.fromJson(Map<String, dynamic> json) {
    final condStr = json['condition'] as String? ?? 'normal';
    final condition = LightCondition.values.firstWhere(
      (c) => c.name == condStr,
      orElse: () => LightCondition.normal,
    );

    return LightAnalysis(
      condition: condition,
      averageLuminance: (json['averageLuminance'] as num?)?.toDouble() ?? 0.5,
      estimatedLux: (json['estimatedLux'] as num?)?.toDouble() ?? 500.0,
      torchRecommended: json['torchRecommended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition.name,
        'averageLuminance': averageLuminance,
        'estimatedLux': estimatedLux,
        'torchRecommended': torchRecommended,
      };
}

/// Skew/tilt angle analysis results.
class SkewAnalysis {
  /// Detected skew angle in degrees.
  final double angleDegrees;

  /// Whether the document appears properly aligned (< 5° skew).
  final bool isAligned;

  /// Recommended correction angle in degrees (negative = rotate clockwise).
  final double correctionAngle;

  const SkewAnalysis({
    required this.angleDegrees,
    required this.isAligned,
    required this.correctionAngle,
  });

  factory SkewAnalysis.fromJson(Map<String, dynamic> json) {
    return SkewAnalysis(
      angleDegrees: (json['angleDegrees'] as num?)?.toDouble() ?? 0.0,
      isAligned: json['isAligned'] as bool? ?? true,
      correctionAngle: (json['correctionAngle'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'angleDegrees': angleDegrees,
        'isAligned': isAligned,
        'correctionAngle': correctionAngle,
      };
}

/// Contrast analysis results.
class ContrastAnalysis {
  /// Contrast ratio (higher = better separation between light and dark).
  final double contrastRatio;

  /// Whether contrast is adequate for scanning.
  final bool isAdequate;

  /// Dynamic range of pixel values (0-255 scale).
  final int dynamicRange;

  const ContrastAnalysis({
    required this.contrastRatio,
    required this.isAdequate,
    required this.dynamicRange,
  });

  factory ContrastAnalysis.fromJson(Map<String, dynamic> json) {
    return ContrastAnalysis(
      contrastRatio: (json['contrastRatio'] as num?)?.toDouble() ?? 0.8,
      isAdequate: json['isAdequate'] as bool? ?? true,
      dynamicRange: json['dynamicRange'] as int? ?? 200,
    );
  }

  Map<String, dynamic> toJson() => {
        'contrastRatio': contrastRatio,
        'isAdequate': isAdequate,
        'dynamicRange': dynamicRange,
      };
}

/// Enterprise scan quality analyzer providing comprehensive blur detection,
/// low-light analysis, skew detection, and contrast evaluation with
/// human-readable quality grades and actionable recommendations.
class ScanQualityAnalyzer {
  /// Performs comprehensive quality analysis on grayscale image bytes.
  ///
  /// [imageBytes] — Raw grayscale pixel data (1 byte per pixel).
  /// [width] and [height] — Image dimensions in pixels.
  static ScanQualityReport analyze(
    Uint8List imageBytes, {
    required int width,
    required int height,
  }) {
    final stopwatch = Stopwatch()..start();

    final blur = analyzeBlur(imageBytes, width: width, height: height);
    final light = analyzeLight(imageBytes);
    final skew = analyzeSkew(imageBytes, width: width, height: height);
    final contrast = analyzeContrast(imageBytes);

    // Calculate overall score as weighted average
    final blurWeight = 0.35;
    final lightWeight = 0.25;
    final skewWeight = 0.15;
    final contrastWeight = 0.25;

    final blurScore = 1.0 - blur.score;
    final lightScore = _lightConditionScore(light.condition);
    final skewScore = skew.isAligned ? 1.0 : math.max(0.0, 1.0 - (skew.angleDegrees.abs() / 45.0));
    final contrastScore = contrast.isAdequate ? 1.0 : contrast.contrastRatio.clamp(0.0, 1.0);

    final overallScore = (blurScore * blurWeight +
            lightScore * lightWeight +
            skewScore * skewWeight +
            contrastScore * contrastWeight)
        .clamp(0.0, 1.0);

    final grade = _scoreToGrade(overallScore);
    final recommendations = _generateRecommendations(blur, light, skew, contrast);

    stopwatch.stop();

    return ScanQualityReport(
      grade: grade,
      overallScore: overallScore,
      blur: blur,
      light: light,
      skew: skew,
      contrast: contrast,
      recommendations: recommendations,
      analysisTime: stopwatch.elapsed,
    );
  }

  /// Analyzes blur level using discrete Laplacian operator.
  static BlurAnalysis analyzeBlur(
    Uint8List imageBytes, {
    required int width,
    required int height,
  }) {
    if (imageBytes.isEmpty || width <= 2 || height <= 2) {
      return const BlurAnalysis(
        severity: BlurSeverity.heavy,
        score: 1.0,
        laplacianVariance: 0.0,
      );
    }

    // Compute discrete Laplacian variance as blur metric
    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    for (int y = 1; y < height - 1 && y * width < imageBytes.length; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        if (idx + width < imageBytes.length && idx - width >= 0) {
          // Laplacian kernel: [0,-1,0; -1,4,-1; 0,-1,0]
          final laplacian = 4 * imageBytes[idx] -
              imageBytes[idx - 1] -
              imageBytes[idx + 1] -
              imageBytes[idx - width] -
              imageBytes[idx + width];
          sum += laplacian;
          sumSquared += laplacian * laplacian;
          count++;
        }
      }
    }

    if (count == 0) {
      return const BlurAnalysis(
        severity: BlurSeverity.heavy,
        score: 1.0,
        laplacianVariance: 0.0,
      );
    }

    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    final normalizedVariance = variance.abs();

    // Map variance to blur severity
    final BlurSeverity severity;
    final double blurScore;

    if (normalizedVariance > 500) {
      severity = BlurSeverity.sharp;
      blurScore = 0.0;
    } else if (normalizedVariance > 200) {
      severity = BlurSeverity.mild;
      blurScore = 0.25;
    } else if (normalizedVariance > 50) {
      severity = BlurSeverity.moderate;
      blurScore = 0.6;
    } else {
      severity = BlurSeverity.heavy;
      blurScore = 0.9;
    }

    return BlurAnalysis(
      severity: severity,
      score: blurScore,
      laplacianVariance: normalizedVariance,
    );
  }

  /// Analyzes ambient light conditions from frame luminance.
  static LightAnalysis analyzeLight(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      return const LightAnalysis(
        condition: LightCondition.tooLow,
        averageLuminance: 0.0,
        estimatedLux: 0.0,
        torchRecommended: true,
      );
    }

    // Calculate average luminance
    double totalLuminance = 0;
    for (int i = 0; i < imageBytes.length; i++) {
      totalLuminance += imageBytes[i];
    }
    final avgLuminance = totalLuminance / imageBytes.length / 255.0;

    // Estimate lux from normalized luminance (rough approximation)
    final estimatedLux = avgLuminance * 1000.0;

    final LightCondition condition;
    final bool torchRecommended;

    if (avgLuminance < 0.08) {
      condition = LightCondition.tooLow;
      torchRecommended = true;
    } else if (avgLuminance < 0.20) {
      condition = LightCondition.low;
      torchRecommended = true;
    } else if (avgLuminance < 0.70) {
      condition = LightCondition.normal;
      torchRecommended = false;
    } else if (avgLuminance < 0.90) {
      condition = LightCondition.bright;
      torchRecommended = false;
    } else {
      condition = LightCondition.overexposed;
      torchRecommended = false;
    }

    return LightAnalysis(
      condition: condition,
      averageLuminance: avgLuminance,
      estimatedLux: estimatedLux,
      torchRecommended: torchRecommended,
    );
  }

  /// Analyzes document skew/tilt angle from edge pixel patterns.
  static SkewAnalysis analyzeSkew(
    Uint8List imageBytes, {
    required int width,
    required int height,
  }) {
    if (imageBytes.isEmpty || width <= 2 || height <= 2) {
      return const SkewAnalysis(
        angleDegrees: 0.0,
        isAligned: true,
        correctionAngle: 0.0,
      );
    }

    // Detect dominant edge direction using Sobel-like horizontal gradient
    double sumAngle = 0;
    int edgeCount = 0;

    for (int y = 1; y < height - 1 && y * width < imageBytes.length; y++) {
      for (int x = 1; x < width - 1; x++) {
        final idx = y * width + x;
        if (idx + width < imageBytes.length && idx - width >= 0) {
          // Horizontal Sobel: [-1, 0, 1]
          final gx = imageBytes[idx + 1] - imageBytes[idx - 1];
          // Vertical Sobel: [-1, 0, 1]
          final gy = imageBytes[idx + width] - imageBytes[idx - width];

          final magnitude = math.sqrt(gx * gx + gy * gy);
          if (magnitude > 30) {
            // Strong edge detected
            final angle = math.atan2(gy.toDouble(), gx.toDouble()) *
                (180.0 / math.pi);
            sumAngle += angle;
            edgeCount++;
          }
        }
      }
    }

    if (edgeCount == 0) {
      return const SkewAnalysis(
        angleDegrees: 0.0,
        isAligned: true,
        correctionAngle: 0.0,
      );
    }

    final avgAngle = sumAngle / edgeCount;
    // Normalize to deviation from horizontal/vertical
    final skewAngle = (avgAngle % 90.0).abs();
    final normalizedSkew =
        skewAngle > 45.0 ? 90.0 - skewAngle : skewAngle;

    return SkewAnalysis(
      angleDegrees: normalizedSkew,
      isAligned: normalizedSkew < 5.0,
      correctionAngle: -normalizedSkew,
    );
  }

  /// Analyzes contrast quality of the image.
  static ContrastAnalysis analyzeContrast(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      return const ContrastAnalysis(
        contrastRatio: 0.0,
        isAdequate: false,
        dynamicRange: 0,
      );
    }

    int minVal = 255;
    int maxVal = 0;

    for (int i = 0; i < imageBytes.length; i++) {
      if (imageBytes[i] < minVal) minVal = imageBytes[i];
      if (imageBytes[i] > maxVal) maxVal = imageBytes[i];
    }

    final dynamicRange = maxVal - minVal;
    final contrastRatio = dynamicRange / 255.0;

    return ContrastAnalysis(
      contrastRatio: contrastRatio,
      isAdequate: contrastRatio > 0.3,
      dynamicRange: dynamicRange,
    );
  }

  // --- Internal Helpers ---

  static double _lightConditionScore(LightCondition condition) {
    switch (condition) {
      case LightCondition.tooLow:
        return 0.1;
      case LightCondition.low:
        return 0.4;
      case LightCondition.normal:
        return 1.0;
      case LightCondition.bright:
        return 0.9;
      case LightCondition.overexposed:
        return 0.3;
    }
  }

  static QualityGrade _scoreToGrade(double score) {
    if (score >= 0.85) return QualityGrade.excellent;
    if (score >= 0.70) return QualityGrade.good;
    if (score >= 0.50) return QualityGrade.acceptable;
    if (score >= 0.30) return QualityGrade.poor;
    return QualityGrade.unusable;
  }

  static List<String> _generateRecommendations(
    BlurAnalysis blur,
    LightAnalysis light,
    SkewAnalysis skew,
    ContrastAnalysis contrast,
  ) {
    final recommendations = <String>[];

    if (!blur.isSharp) {
      if (blur.severity == BlurSeverity.heavy) {
        recommendations.add(
            '📸 Image is heavily blurred. Hold device steady or tap to refocus.');
      } else {
        recommendations
            .add('📸 Slight blur detected. Consider tapping to lock focus.');
      }
    }

    if (light.torchRecommended) {
      recommendations
          .add('💡 Low light detected. Enable torch/flash for better results.');
    }
    if (light.condition == LightCondition.overexposed) {
      recommendations.add(
          '☀️ Image is overexposed. Move away from direct light or reduce exposure.');
    }

    if (!skew.isAligned) {
      recommendations.add(
          '📐 Document appears tilted (${skew.angleDegrees.toStringAsFixed(1)}°). Align edges with the guide frame.');
    }

    if (!contrast.isAdequate) {
      recommendations.add(
          '🎨 Low contrast detected. Ensure document is on a contrasting background.');
    }

    if (recommendations.isEmpty) {
      recommendations.add('✅ Image quality is excellent. Ready to scan.');
    }

    return recommendations;
  }
}
