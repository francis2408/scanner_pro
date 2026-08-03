import 'package:flutter/foundation.dart';

/// Real-time operational performance telemetry metrics exposed by ScannerPro SDK.
@immutable
class ScannerStats {
  /// Estimated live camera frame detection rate (frames per second).
  final double fps;

  /// Average frame processing duration in milliseconds.
  final double processingTimeMs;

  /// Estimated memory usage in megabytes (MB).
  final double memoryMb;

  /// Total count of frames skipped due to throttling, blur, or static scene detection.
  final int droppedFrames;

  /// Total count of frame passes successfully processed by ML Kit vision models.
  final int processedFrames;

  /// Estimated CPU load percentage (0.0 to 100.0%).
  final double cpuUsageEstimate;

  /// Timestamp when stats snapshot was captured.
  final DateTime timestamp;

  /// Constructs a [ScannerStats] telemetry snapshot.
  ScannerStats({
    this.fps = 0.0,
    this.processingTimeMs = 0.0,
    this.memoryMb = 0.0,
    this.droppedFrames = 0,
    this.processedFrames = 0,
    this.cpuUsageEstimate = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Default initial empty stats.
  static final ScannerStats empty = ScannerStats();

  /// Creates a copy of [ScannerStats] with modified metrics.
  ScannerStats copyWith({
    double? fps,
    double? processingTimeMs,
    double? memoryMb,
    int? droppedFrames,
    int? processedFrames,
    double? cpuUsageEstimate,
    DateTime? timestamp,
  }) {
    return ScannerStats(
      fps: fps ?? this.fps,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      memoryMb: memoryMb ?? this.memoryMb,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      processedFrames: processedFrames ?? this.processedFrames,
      cpuUsageEstimate: cpuUsageEstimate ?? this.cpuUsageEstimate,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Converts stats payload to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'fps': double.parse(fps.toStringAsFixed(1)),
      'processingTimeMs': double.parse(processingTimeMs.toStringAsFixed(1)),
      'memoryMb': double.parse(memoryMb.toStringAsFixed(1)),
      'droppedFrames': droppedFrames,
      'processedFrames': processedFrames,
      'cpuUsageEstimate': double.parse(cpuUsageEstimate.toStringAsFixed(1)),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ScannerStats(fps: ${fps.toStringAsFixed(1)}, latency: ${processingTimeMs.toStringAsFixed(1)}ms, memory: ${memoryMb.toStringAsFixed(1)}MB, dropped: $droppedFrames, processed: $processedFrames)';
  }
}
