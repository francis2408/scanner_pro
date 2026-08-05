import 'dart:typed_data';
import 'document_scanner_service.dart';
import 'scan_quality_analyzer.dart';

/// Single scanned document page model (Scanbot SDK style page architecture).
class DocumentPage {
  /// Unique page identifier.
  final String id;

  /// Original raw image byte buffer.
  final Uint8List originalBytes;

  /// Processed and filtered image byte buffer.
  Uint8List processedBytes;

  /// Active document enhancement filter applied to this page.
  DocumentFilterMode filterMode;

  /// Quadrilateral corner coordinates of detected document boundaries.
  DocumentCorners corners;

  /// Document quality analysis metrics for this page.
  final ScanQualityReport qualityReport;

  /// Creation timestamp of page capture.
  final DateTime timestamp;

  /// Page width in pixels.
  final int width;

  /// Page height in pixels.
  final int height;

  /// Constructs a [DocumentPage].
  DocumentPage({
    required this.id,
    required this.originalBytes,
    Uint8List? processedBytes,
    this.filterMode = DocumentFilterMode.original,
    required this.corners,
    ScanQualityReport? qualityReport,
    DateTime? timestamp,
    this.width = 640,
    this.height = 480,
  })  : processedBytes = processedBytes ?? originalBytes,
        qualityReport = qualityReport ??
            ScanQualityAnalyzer.analyze(originalBytes, width: width, height: height),
        timestamp = timestamp ?? DateTime.now();

  /// Applies a new [DocumentFilterMode] to this page and updates [processedBytes].
  void applyFilter(DocumentFilterMode filter) {
    filterMode = filter;
    processedBytes = DocumentScannerService.applyFilter(
      originalBytes,
      filter,
      width: width,
      height: height,
    );
  }

  /// Updates polygon quadrilateral corners for perspective cropping.
  void updateCorners(DocumentCorners newCorners) {
    corners = newCorners;
  }

  /// Creates a defensive copy of this page.
  DocumentPage copyWith({
    String? id,
    Uint8List? originalBytes,
    Uint8List? processedBytes,
    DocumentFilterMode? filterMode,
    DocumentCorners? corners,
    ScanQualityReport? qualityReport,
    DateTime? timestamp,
    int? width,
    int? height,
  }) {
    return DocumentPage(
      id: id ?? this.id,
      originalBytes: originalBytes ?? this.originalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      filterMode: filterMode ?? this.filterMode,
      corners: corners ?? this.corners,
      qualityReport: qualityReport ?? this.qualityReport,
      timestamp: timestamp ?? this.timestamp,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filterMode': filterMode.name,
      'corners': corners.toList().map((c) => {'x': c.dx, 'y': c.dy}).toList(),
      'qualityGrade': qualityReport.grade.letterGrade,
      'qualityScore': qualityReport.overallScore,
      'width': width,
      'height': height,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
