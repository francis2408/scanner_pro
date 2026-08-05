import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import '../core/services/document_page.dart';
import '../core/services/document_scan_session.dart';
import '../core/services/document_scanner_service.dart';
import '../scannerpro_facade.dart';
import '../ui/widgets/universal_scanner_view.dart';
import 'scanner_controller.dart';

/// Configuration options for Scanbot SDK document scanner UI.
class ScanbotDocumentScannerConfig {
  final bool autoSnapping;
  final double autoSnappingSensitivity;
  final DocumentFilterMode defaultFilter;
  final bool enableMultiPage;
  final int? maxPageCount;

  const ScanbotDocumentScannerConfig({
    this.autoSnapping = true,
    this.autoSnappingSensitivity = 0.85,
    this.defaultFilter = DocumentFilterMode.original,
    this.enableMultiPage = true,
    this.maxPageCount,
  });
}

/// Configuration options for Scanbot SDK barcode scanner UI.
class ScanbotBarcodeScannerConfig {
  final List<String>? barcodeFormats;
  final bool enableBatchScan;
  final int? maxBatchCount;

  const ScanbotBarcodeScannerConfig({
    this.barcodeFormats,
    this.enableBatchScan = false,
    this.maxBatchCount,
  });
}

/// High-level facade mirroring Scanbot SDK package API patterns.
class ScanbotSdk {
  /// Start a document scanning flow (`scanbot_sdk` document scanner).
  static Future<DocumentScanSession> startDocumentScanner({
    ScanbotDocumentScannerConfig config = const ScanbotDocumentScannerConfig(),
  }) async {
    final session = DocumentScanSession(
      id: 'doc_sb_${DateTime.now().millisecondsSinceEpoch}',
      maxPages: config.maxPageCount,
    );
    return session;
  }

  /// Perform OCR text extraction (`scanbot_sdk` performOcr API).
  static Future<ScanResult> performOcr(
    dynamic input, {
    List<String>? languages,
  }) async {
    return await ScannerPro.scanOcr(input);
  }

  /// Single or batch barcode scanner execution (`scanbot_sdk` barcode scanner).
  static Future<ScanResult> scanBarcode(
    dynamic input, {
    ScanbotBarcodeScannerConfig config = const ScanbotBarcodeScannerConfig(),
  }) async {
    return await ScannerPro.scanBarcode(input);
  }

  /// Create a multi-page PDF document from scanned pages (`scanbot_sdk` createPdf API).
  static Uint8List createPdf(
    List<DocumentPage> pages, {
    String title = 'Scanbot SDK Document Export',
    String? watermarkText,
    String? password,
  }) {
    final session = DocumentScanSession(id: 'pdf_export');
    for (final page in pages) {
      session.addPage(
        imageBytes: page.processedBytes,
        filterMode: page.filterMode,
        corners: page.corners,
        width: page.width,
        height: page.height,
      );
    }
    return session.exportToPdf(
      title: title,
      watermarkText: watermarkText,
      password: password,
    );
  }

  /// Applies perspective crop and document enhancement filter to image bytes (`scanbot_sdk` cropping API).
  static Uint8List applyFilterAndCrop(
    Uint8List imageBytes, {
    required DocumentCorners corners,
    DocumentFilterMode filter = DocumentFilterMode.original,
    int width = 640,
    int height = 480,
  }) {
    return DocumentScannerService.applyFilter(
      imageBytes,
      filter,
      width: width,
      height: height,
    );
  }
}

/// Scanbot SDK style Document Scanner Viewport widget.
class ScanbotDocumentScannerView extends StatelessWidget {
  final ScannerController? controller;
  final Function(DocumentPage page)? onPageCaptured;
  final Function(DocumentScanSession session)? onSessionCompleted;

  const ScanbotDocumentScannerView({
    super.key,
    this.controller,
    this.onPageCaptured,
    this.onSessionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return UniversalScannerView(
      controller: controller,
      initialMode: ScanMode.document,
      onResultDetected: (res) {
        if (res.rawBytes != null && res.corners != null && res.corners!.length >= 4) {
          final page = DocumentPage(
            id: 'page_${DateTime.now().millisecondsSinceEpoch}',
            originalBytes: res.rawBytes!,
            corners: DocumentCorners(
              topLeft: res.corners![0],
              topRight: res.corners![1],
              bottomRight: res.corners![2],
              bottomLeft: res.corners![3],
            ),
          );
          onPageCaptured?.call(page);
        }
      },
    );
  }
}
