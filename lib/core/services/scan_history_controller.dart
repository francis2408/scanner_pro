import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/scan_result.dart';
import '../models/scanner_mode.dart';
import 'csv_exporter.dart';
import 'json_exporter.dart';
import 'pdf_exporter.dart';

/// Dedicated controller for managing, filtering, and exporting scan result history.
class ScanHistoryController extends ChangeNotifier {
  final int maxHistorySize;
  final List<ScanResult> _history = [];
  final StreamController<List<ScanResult>> _historyStreamController =
      StreamController<List<ScanResult>>.broadcast();

  /// Constructs a [ScanHistoryController].
  ScanHistoryController({this.maxHistorySize = 100});

  /// Unmodifiable list of recorded scan results.
  List<ScanResult> get history => List.unmodifiable(_history);

  /// Total count of items in history log.
  int get length => _history.length;

  /// Whether scan history log is empty.
  bool get isEmpty => _history.isEmpty;

  /// Stream emitting updated scan history snapshots on changes.
  Stream<List<ScanResult>> get historyStream =>
      _historyStreamController.stream;

  /// Adds a new [ScanResult] to history and trims beyond [maxHistorySize].
  void add(ScanResult result) {
    _history.insert(0, result);
    if (_history.length > maxHistorySize) {
      _history.removeRange(maxHistorySize, _history.length);
    }
    _notify();
  }

  /// Adds multiple results to history log.
  void addAll(List<ScanResult> results) {
    for (final res in results) {
      _history.insert(0, res);
    }
    if (_history.length > maxHistorySize) {
      _history.removeRange(maxHistorySize, _history.length);
    }
    _notify();
  }

  /// Removes a scan result item at specified index.
  void removeAt(int index) {
    if (index >= 0 && index < _history.length) {
      _history.removeAt(index);
      _notify();
    }
  }

  /// Clears all recorded scan results from history log.
  void clear() {
    _history.clear();
    _notify();
  }

  /// Filters scan history by matching [ScanMode].
  List<ScanResult> filterByMode(ScanMode mode) {
    return _history.where((item) => item.mode == mode).toList();
  }

  /// Filters scan history by search query term in raw payload or fields.
  List<ScanResult> search(String query) {
    final term = query.toLowerCase();
    return _history.where((item) {
      if (item.rawValue.toLowerCase().contains(term)) return true;
      return item.fields.values
          .any((val) => val.toLowerCase().contains(term));
    }).toList();
  }

  /// Exports current history log as formatted JSON string.
  String exportToJson({bool pretty = true}) {
    return JsonExporter.exportToJson(_history, prettyPrint: pretty);
  }

  /// Exports current history log as formatted CSV string.
  String exportToCsv() {
    return CsvExporter.exportToCsv(_history);
  }

  /// Exports current history log as enterprise PDF binary byte array buffer.
  Future<Uint8List> exportToPdf({String title = 'Scan History Report'}) async {
    return PdfExporter.exportResultsToPdf(
      results: _history,
      title: title,
    );
  }

  void _notify() {
    notifyListeners();
    if (!_historyStreamController.isClosed) {
      _historyStreamController.add(List.unmodifiable(_history));
    }
  }

  @override
  void dispose() {
    _historyStreamController.close();
    super.dispose();
  }
}
