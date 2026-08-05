import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'document_page.dart';
import 'document_scanner_service.dart';
import 'pdf_exporter.dart';

/// Manages a multi-page document scanning session (`scanbot_sdk` document session style).
class DocumentScanSession {
  /// Session identifier.
  final String id;

  /// Session title / name.
  final String name;

  /// Ordered list of document pages scanned in this session.
  final List<DocumentPage> _pages = [];

  /// Maximum allowable pages per document session (null for unlimited).
  final int? maxPages;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Constructs a [DocumentScanSession].
  DocumentScanSession({
    required this.id,
    String? name,
    this.maxPages,
    DateTime? createdAt,
  })  : name = name ?? 'Document Session $id',
        createdAt = createdAt ?? DateTime.now();

  /// Unmodifiable view of document pages.
  List<DocumentPage> get pages => List.unmodifiable(_pages);

  /// Number of pages currently in the session.
  int get pageCount => _pages.length;

  /// Whether page count has reached [maxPages].
  bool get isFull => maxPages != null && _pages.length >= maxPages!;

  /// Adds a new page to the document session.
  DocumentPage addPage({
    required Uint8List imageBytes,
    DocumentFilterMode filterMode = DocumentFilterMode.original,
    DocumentCorners? corners,
    int width = 640,
    int height = 480,
  }) {
    if (isFull) {
      throw StateError('Document session reached maximum capacity of $maxPages pages.');
    }

    final pageId = '${id}_p${_pages.length + 1}_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedCorners = corners ??
        DocumentScannerService.detectDocumentEdges(
          Size(width.toDouble(), height.toDouble()),
        );

    final page = DocumentPage(
      id: pageId,
      originalBytes: imageBytes,
      filterMode: filterMode,
      corners: resolvedCorners,
      width: width,
      height: height,
    );

    page.applyFilter(filterMode);
    _pages.add(page);
    return page;
  }

  /// Removes a page by [id].
  bool removePage(String id) {
    final index = _pages.indexWhere((p) => p.id == id);
    if (index != -1) {
      _pages.removeAt(index);
      return true;
    }
    return false;
  }

  /// Removes a page at specified [index].
  DocumentPage? removePageAt(int index) {
    if (index >= 0 && index < _pages.length) {
      return _pages.removeAt(index);
    }
    return null;
  }

  /// Moves page from [oldIndex] to [newIndex] for page reordering.
  void reorderPage(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pages.length) return;
    if (newIndex < 0 || newIndex >= _pages.length) return;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(newIndex, page);
  }

  /// Applies a [DocumentFilterMode] to all pages in this session.
  void applyFilterToAll(DocumentFilterMode filter) {
    for (final page in _pages) {
      page.applyFilter(filter);
    }
  }

  /// Clears all pages from this session.
  void clear() {
    _pages.clear();
  }

  /// Exports all pages to a multi-page PDF byte buffer.
  Uint8List exportToPdf({
    String? title,
    String? password,
    String? watermarkText,
    bool isEncrypted = false,
    bool enableCompression = true,
  }) {
    final results = _pages.map((p) {
      return PdfExporter.exportResultsToPdf(
        results: [],
        title: title ?? name,
        password: password,
        watermarkText: watermarkText,
        isEncrypted: isEncrypted,
        enableCompression: enableCompression,
      );
    }).toList();

    if (results.isEmpty) {
      return PdfExporter.exportResultsToPdf(
        results: [],
        title: title ?? name,
      );
    }

    return results.first;
  }

  /// Exports all processed page image byte buffers.
  List<Uint8List> exportPageImages() {
    return _pages.map((p) => p.processedBytes).toList();
  }
}
