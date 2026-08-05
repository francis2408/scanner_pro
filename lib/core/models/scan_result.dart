import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'ocr_text_result.dart';
import 'scanner_mode.dart';

import '../parsers/bank_cheque_parser.dart';

/// Detailed result structure for individual detected barcodes in multi-barcode scanning mode.
@immutable
class BarcodeResult {
  final String format;
  final String rawValue;
  final String? displayValue;
  final Rect? boundingBox;
  final List<Offset>? corners;
  final Uint8List? rawBytes;

  const BarcodeResult({
    required this.format,
    required this.rawValue,
    this.displayValue,
    this.boundingBox,
    this.corners,
    this.rawBytes,
  });

  factory BarcodeResult.fromJson(Map<String, dynamic> json) {
    Rect? box;
    if (json['boundingBox'] != null && json['boundingBox'] is Map) {
      final b = json['boundingBox'] as Map<String, dynamic>;
      box = Rect.fromLTWH(
        (b['left'] as num).toDouble(),
        (b['top'] as num).toDouble(),
        (b['width'] as num).toDouble(),
        (b['height'] as num).toDouble(),
      );
    }

    List<Offset>? points;
    if (json['corners'] != null && json['corners'] is List) {
      points = (json['corners'] as List)
          .map((c) {
            final m = c as Map<String, dynamic>;
            return Offset(
              (m['x'] as num).toDouble(),
              (m['y'] as num).toDouble(),
            );
          })
          .toList();
    }

    return BarcodeResult(
      format: json['format'] as String? ?? 'UNKNOWN',
      rawValue: json['rawValue'] as String? ?? '',
      displayValue: json['displayValue'] as String?,
      boundingBox: box,
      corners: points,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': format,
        'rawValue': rawValue,
        'displayValue': displayValue ?? rawValue,
        'boundingBox': boundingBox != null
            ? {
                'left': boundingBox!.left,
                'top': boundingBox!.top,
                'width': boundingBox!.width,
                'height': boundingBox!.height,
              }
            : null,
        'corners': corners?.map((c) => {'x': c.dx, 'y': c.dy}).toList(),
      };

  @override
  String toString() => 'BarcodeResult(format: $format, rawValue: $rawValue)';
}

/// Document image quality metrics calculated during isolate preprocessing.
@immutable
class DocumentQualityScore {
  final double blurScore;
  final double brightnessScore;
  final double contrastScore;
  final double overallQuality;
  final bool isHighQuality;

  const DocumentQualityScore({
    required this.blurScore,
    required this.brightnessScore,
    required this.contrastScore,
    required this.overallQuality,
    required this.isHighQuality,
  });

  factory DocumentQualityScore.fromJson(Map<String, dynamic> json) {
    return DocumentQualityScore(
      blurScore: (json['blurScore'] as num?)?.toDouble() ?? 0.0,
      brightnessScore: (json['brightnessScore'] as num?)?.toDouble() ?? 0.0,
      contrastScore: (json['contrastScore'] as num?)?.toDouble() ?? 0.0,
      overallQuality: (json['overallQuality'] as num?)?.toDouble() ?? 0.0,
      isHighQuality: json['isHighQuality'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'blurScore': blurScore,
        'brightnessScore': brightnessScore,
        'contrastScore': contrastScore,
        'overallQuality': overallQuality,
        'isHighQuality': isHighQuality,
      };

  @override
  String toString() =>
      'DocumentQualityScore(overall: ${(overallQuality * 100).toStringAsFixed(1)}%, highQuality: $isHighQuality)';
}

/// Represents the extracted structured data resulting from a camera or image scan.
class ScanResult {
  /// The scanning mode used during extraction.
  final ScanMode mode;

  /// The original unparsed raw text payload from the OCR or Barcode detector.
  final String rawValue;

  /// Map of key-value parsed attributes extracted from the document or code.
  final Map<String, String> fields;

  /// Flag indicating whether validation or checksum verification passed.
  final bool isValid;

  /// Detection confidence score ranging from 0.0 to 1.0.
  final double confidence;

  /// Timestamp when the scan occurred.
  final DateTime timestamp;

  /// Optional file path to captured camera frame image.
  final String? imagePath;

  /// Optional raw byte buffer of the scanned image frame.
  final Uint8List? rawBytes;

  /// Detected barcode format or document type specification.
  final String? format;

  /// Classified document category string (e.g. invoice, receipt, passport, aadhaar, pan, vin).
  final String? documentCategory;

  /// Region of Interest (ROI) sub-rectangle cutout in frame pixel coordinates.
  final Rect? roi;

  /// List of image enhancement filters applied during isolate preprocessing.
  final List<String> enhancementsApplied;

  /// Whether this result was identified as a duplicate during session caching.
  final bool isDuplicate;

  /// Detected barcode or document corner points in frame pixel coordinates.
  final List<Offset>? corners;

  /// Detected bounding box rectangle in frame pixel coordinates.
  final Rect? boundingBox;

  /// Input frame or image resolution size.
  final Size? imageSize;

  /// Total execution duration elapsed during frame detection and parsing.
  final Duration? scanDuration;

  /// Additional raw metadata key-values.
  final Map<String, dynamic> metadata;

  /// List of individual scan results detected in a multi-code pass.
  final List<ScanResult>? multiResults;

  /// Calculated document quality score metrics (blur, contrast, brightness).
  final DocumentQualityScore? qualityScore;

  /// Confidence score achieved via temporal multi-frame consensus voting (up to 0.99 = 99%).
  final double? consensusConfidence;

  /// Detailed checklist of verification tests performed and their pass/fail statuses.
  final Map<String, bool> verifications;

  /// Processing algorithms and enhancements metadata applied to the input image.
  final Map<String, dynamic> preprocessingInfo;

  /// Parsed details from a Bank Cheque MICR codeline if mode is ScanMode.cheque.
  final BankChequeInfo? bankChequeInfo;

  /// Explicit list of individual detected barcodes in multi-barcode scanning mode.
  final List<BarcodeResult>? detectedBarcodes;

  /// Session identifier for multi-scan session tracking.
  final String? sessionId;

  /// Export format used (PDF, JPG, PNG) for export metadata tracking.
  final String? exportFormat;

  /// Encryption status indicator for encrypted storage tracking.
  final String? encryptionStatus;

  /// Whether a watermark has been applied to this scan's output.
  final bool watermarkApplied;

  /// Full structured OCR text result (blocks, lines, elements).
  final OcrTextResult? ocrTextResult;

  /// Creates a new [ScanResult] instance.
  ScanResult({
    required this.mode,
    required this.rawValue,
    Map<String, String>? fields,
    this.isValid = true,
    this.confidence = 1.0,
    DateTime? timestamp,
    this.imagePath,
    this.rawBytes,
    this.format,
    this.documentCategory,
    this.roi,
    List<String>? enhancementsApplied,
    this.isDuplicate = false,
    this.corners,
    this.boundingBox,
    this.imageSize,
    this.scanDuration,
    Map<String, dynamic>? metadata,
    this.multiResults,
    this.qualityScore,
    this.consensusConfidence,
    Map<String, bool>? verifications,
    Map<String, dynamic>? preprocessingInfo,
    this.bankChequeInfo,
    this.detectedBarcodes,
    this.sessionId,
    this.exportFormat,
    this.encryptionStatus,
    this.watermarkApplied = false,
    this.ocrTextResult,
  })  : fields = fields ?? const {},
        timestamp = timestamp ?? DateTime.now(),
        enhancementsApplied = enhancementsApplied ?? const [],
        metadata = metadata ?? {},
        verifications = verifications ?? const {},
        preprocessingInfo = preprocessingInfo ?? const {};

  /// Convenience getter returning list of [BarcodeResult] detected in frame.
  List<BarcodeResult> get barcodes {
    if (detectedBarcodes != null && detectedBarcodes!.isNotEmpty) {
      return detectedBarcodes!;
    }
    if (multiResults != null && multiResults!.isNotEmpty) {
      return multiResults!
          .map((res) => BarcodeResult(
                format: res.format ?? 'UNKNOWN',
                rawValue: res.rawValue,
                displayValue: res.rawValue,
                boundingBox: res.boundingBox,
                corners: res.corners,
                rawBytes: res.rawBytes,
              ))
          .toList();
    }
    if (rawValue.isNotEmpty) {
      return [
        BarcodeResult(
          format: format ?? 'UNKNOWN',
          rawValue: rawValue,
          displayValue: rawValue,
          boundingBox: boundingBox,
          corners: corners,
          rawBytes: rawBytes,
        ),
      ];
    }
    return const [];
  }

  /// Creates a copy of [ScanResult] with updated fields.
  ScanResult copyWith({
    ScanMode? mode,
    String? rawValue,
    Map<String, String>? fields,
    bool? isValid,
    double? confidence,
    DateTime? timestamp,
    String? imagePath,
    Uint8List? rawBytes,
    String? format,
    String? documentCategory,
    Rect? roi,
    List<String>? enhancementsApplied,
    bool? isDuplicate,
    List<Offset>? corners,
    Rect? boundingBox,
    Size? imageSize,
    Duration? scanDuration,
    Map<String, dynamic>? metadata,
    List<ScanResult>? multiResults,
    DocumentQualityScore? qualityScore,
    double? consensusConfidence,
    Map<String, bool>? verifications,
    Map<String, dynamic>? preprocessingInfo,
    BankChequeInfo? bankChequeInfo,
    List<BarcodeResult>? detectedBarcodes,
    String? sessionId,
    String? exportFormat,
    String? encryptionStatus,
    bool? watermarkApplied,
    OcrTextResult? ocrTextResult,
  }) {
    return ScanResult(
      mode: mode ?? this.mode,
      rawValue: rawValue ?? this.rawValue,
      fields: fields ?? this.fields,
      isValid: isValid ?? this.isValid,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      rawBytes: rawBytes ?? this.rawBytes,
      format: format ?? this.format,
      documentCategory: documentCategory ?? this.documentCategory,
      roi: roi ?? this.roi,
      enhancementsApplied: enhancementsApplied ?? this.enhancementsApplied,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      corners: corners ?? this.corners,
      boundingBox: boundingBox ?? this.boundingBox,
      imageSize: imageSize ?? this.imageSize,
      scanDuration: scanDuration ?? this.scanDuration,
      metadata: metadata ?? this.metadata,
      multiResults: multiResults ?? this.multiResults,
      qualityScore: qualityScore ?? this.qualityScore,
      consensusConfidence: consensusConfidence ?? this.consensusConfidence,
      verifications: verifications ?? this.verifications,
      preprocessingInfo: preprocessingInfo ?? this.preprocessingInfo,
      bankChequeInfo: bankChequeInfo ?? this.bankChequeInfo,
      detectedBarcodes: detectedBarcodes ?? this.detectedBarcodes,
      sessionId: sessionId ?? this.sessionId,
      exportFormat: exportFormat ?? this.exportFormat,
      encryptionStatus: encryptionStatus ?? this.encryptionStatus,
      watermarkApplied: watermarkApplied ?? this.watermarkApplied,
      ocrTextResult: ocrTextResult ?? this.ocrTextResult,
    );
  }

  /// Serializes the scan result to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'title': mode.title,
      'rawValue': rawValue,
      'fields': fields,
      'isValid': isValid,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'format': format ?? metadata['format'],
      'documentCategory': documentCategory,
      'isDuplicate': isDuplicate,
      'enhancementsApplied': enhancementsApplied,
      'corners': corners
          ?.map((c) => {'x': c.dx, 'y': c.dy})
          .toList(),
      'boundingBox': boundingBox != null
          ? {
              'left': boundingBox!.left,
              'top': boundingBox!.top,
              'width': boundingBox!.width,
              'height': boundingBox!.height,
            }
          : null,
      'roi': roi != null
          ? {
              'left': roi!.left,
              'top': roi!.top,
              'width': roi!.width,
              'height': roi!.height,
            }
          : null,
      'imageSize': imageSize != null
          ? {'width': imageSize!.width, 'height': imageSize!.height}
          : null,
      'scanDurationMs': scanDuration?.inMilliseconds,
      'metadata': metadata,
      'qualityScore': qualityScore?.toJson(),
      'consensusConfidence': consensusConfidence,
      'verifications': verifications,
      'preprocessingInfo': preprocessingInfo,
      'bankChequeInfo': bankChequeInfo?.toJson(),
      'detectedBarcodes': detectedBarcodes?.map((b) => b.toJson()).toList(),
      'sessionId': sessionId,
      'exportFormat': exportFormat,
      'encryptionStatus': encryptionStatus,
      'watermarkApplied': watermarkApplied,
      'ocrTextResult': ocrTextResult?.toJson(),
    };
  }

  /// Deserializes a [ScanResult] from a JSON map.
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final modeStr = json['mode'] as String? ?? 'qr';
    final mode = ScanMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ScanMode.qr,
    );

    final fieldsRaw = json['fields'] as Map<String, dynamic>?;
    final fields = fieldsRaw?.map((k, v) => MapEntry(k, v.toString())) ??
        const <String, String>{};

    final metadataRaw = json['metadata'] as Map<String, dynamic>?;
    final metadata = metadataRaw ?? const <String, dynamic>{};

    final verificationsRaw = json['verifications'] as Map<String, dynamic>?;
    final verifications = verificationsRaw?.map((k, v) => MapEntry(k, v == true)) ??
        const <String, bool>{};

    final preprocessingRaw = json['preprocessingInfo'] as Map<String, dynamic>?;
    final preprocessingInfo = preprocessingRaw ?? const <String, dynamic>{};

    List<BarcodeResult>? barcodes;
    if (json['detectedBarcodes'] != null && json['detectedBarcodes'] is List) {
      barcodes = (json['detectedBarcodes'] as List)
          .map((b) => BarcodeResult.fromJson(b as Map<String, dynamic>))
          .toList();
    }

    DocumentQualityScore? quality;
    if (json['qualityScore'] != null && json['qualityScore'] is Map) {
      quality = DocumentQualityScore.fromJson(
          json['qualityScore'] as Map<String, dynamic>);
    }

    BankChequeInfo? cheque;
    if (json['bankChequeInfo'] != null && json['bankChequeInfo'] is Map) {
      cheque = BankChequeInfo.fromJson(
          json['bankChequeInfo'] as Map<String, dynamic>);
    }

    OcrTextResult? ocrResult;
    if (json['ocrTextResult'] != null && json['ocrTextResult'] is Map) {
      ocrResult = OcrTextResult.fromJson(
          json['ocrTextResult'] as Map<String, dynamic>);
    }

    // Deserialize roi rectangle
    Rect? roi;
    if (json['roi'] != null && json['roi'] is Map) {
      final r = json['roi'] as Map<String, dynamic>;
      roi = Rect.fromLTWH(
        (r['left'] as num).toDouble(),
        (r['top'] as num).toDouble(),
        (r['width'] as num).toDouble(),
        (r['height'] as num).toDouble(),
      );
    }

    // Deserialize corner points
    List<Offset>? corners;
    if (json['corners'] != null && json['corners'] is List) {
      corners = (json['corners'] as List)
          .map((c) {
            final m = c as Map<String, dynamic>;
            return Offset(
              (m['x'] as num).toDouble(),
              (m['y'] as num).toDouble(),
            );
          })
          .toList();
    }

    // Deserialize image size
    Size? imageSize;
    if (json['imageSize'] != null && json['imageSize'] is Map) {
      final s = json['imageSize'] as Map<String, dynamic>;
      imageSize = Size(
        (s['width'] as num).toDouble(),
        (s['height'] as num).toDouble(),
      );
    }

    return ScanResult(
      mode: mode,
      rawValue: json['rawValue'] as String? ?? '',
      fields: fields,
      isValid: json['isValid'] as bool? ?? true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      imagePath: json['imagePath'] as String?,
      format: json['format'] as String?,
      documentCategory: json['documentCategory'] as String?,
      roi: roi,
      isDuplicate: json['isDuplicate'] as bool? ?? false,
      corners: corners,
      imageSize: imageSize,
      enhancementsApplied: (json['enhancementsApplied'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      scanDuration: json['scanDurationMs'] != null
          ? Duration(milliseconds: json['scanDurationMs'] as int)
          : null,
      metadata: metadata,
      qualityScore: quality,
      consensusConfidence: (json['consensusConfidence'] as num?)?.toDouble(),
      verifications: verifications,
      preprocessingInfo: preprocessingInfo,
      bankChequeInfo: cheque,
      detectedBarcodes: barcodes,
      sessionId: json['sessionId'] as String?,
      exportFormat: json['exportFormat'] as String?,
      encryptionStatus: json['encryptionStatus'] as String?,
      watermarkApplied: json['watermarkApplied'] as bool? ?? false,
      ocrTextResult: ocrResult,
    );
  }

  /// Creates a failed or error [ScanResult] instance.
  factory ScanResult.error(ScanMode mode, String errorMessage) {
    return ScanResult(
      mode: mode,
      rawValue: errorMessage,
      fields: {'Error': errorMessage},
      isValid: false,
      confidence: 0.0,
    );
  }

  @override
  String toString() {
    return 'ScanResult(mode: ${mode.name}, isValid: $isValid, category: $documentCategory, confidence: $confidence, format: $format, fieldsCount: ${fields.length}, duration: ${scanDuration?.inMilliseconds ?? 0}ms)';
  }
}
