import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/scan_result.dart';
import '../models/scanner_mode.dart';
import 'csv_exporter.dart';
import 'json_exporter.dart';
import 'pdf_exporter.dart';

/// Session lifecycle state.
enum SessionState {
  /// Session has not started.
  idle,

  /// Session is actively scanning.
  active,

  /// Session is temporarily paused.
  paused,

  /// Session has been completed.
  completed,

  /// Session was cancelled without saving.
  cancelled,
}

/// Statistics snapshot for a multi-scan session.
@immutable
class SessionStats {
  /// Total number of items scanned in this session.
  final int totalScans;

  /// Number of valid (successful) scans.
  final int validScans;

  /// Number of invalid or failed scans.
  final int invalidScans;

  /// Number of duplicates detected and filtered.
  final int duplicatesFiltered;

  /// Session start timestamp.
  final DateTime startedAt;

  /// Session end or current timestamp.
  final DateTime? endedAt;

  /// Total session duration.
  final Duration duration;

  /// Scan success rate (0.0 to 1.0).
  final double successRate;

  /// Average time between consecutive scans.
  final Duration? averageScanInterval;

  /// Most frequently scanned mode.
  final ScanMode? dominantMode;

  const SessionStats({
    required this.totalScans,
    required this.validScans,
    required this.invalidScans,
    required this.duplicatesFiltered,
    required this.startedAt,
    this.endedAt,
    required this.duration,
    required this.successRate,
    this.averageScanInterval,
    this.dominantMode,
  });

  Map<String, dynamic> toJson() => {
        'totalScans': totalScans,
        'validScans': validScans,
        'invalidScans': invalidScans,
        'duplicatesFiltered': duplicatesFiltered,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'successRate': successRate,
        'averageScanIntervalMs': averageScanInterval?.inMilliseconds,
        'dominantMode': dominantMode?.name,
      };

  @override
  String toString() =>
      'SessionStats(scans: $totalScans, valid: $validScans, '
      'dupes: $duplicatesFiltered, rate: ${(successRate * 100).toStringAsFixed(1)}%, '
      'duration: ${duration.inSeconds}s)';
}

/// Stateful multi-scan session manager providing lifecycle control,
/// automatic duplicate detection, session statistics, and data export.
class MultiScanSession extends ChangeNotifier {
  /// Unique session identifier.
  final String sessionId;

  /// Optional human-readable session name.
  final String? name;

  /// Whether to automatically filter duplicate scan values within the session.
  final bool enableDuplicateFilter;

  /// Maximum allowed items in a single session (null = unlimited).
  final int? maxItems;

  /// Internal session state.
  SessionState _state = SessionState.idle;

  /// Session start timestamp.
  DateTime? _startedAt;

  /// Session end timestamp.
  DateTime? _endedAt;

  /// All scan results collected in this session.
  final List<ScanResult> _results = [];

  /// Set of raw values seen for duplicate detection.
  final Set<String> _seenValues = {};

  /// Count of duplicates filtered.
  int _duplicatesFiltered = 0;

  /// Timestamps of each scan for interval calculation.
  final List<DateTime> _scanTimestamps = [];

  /// Stream controller for session events.
  final StreamController<ScanResult> _resultStreamController =
      StreamController<ScanResult>.broadcast();

  /// Stream controller for state changes.
  final StreamController<SessionState> _stateStreamController =
      StreamController<SessionState>.broadcast();

  /// Constructs a [MultiScanSession].
  MultiScanSession({
    String? sessionId,
    this.name,
    this.enableDuplicateFilter = true,
    this.maxItems,
  }) : sessionId = sessionId ??
            '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  /// Current session state.
  SessionState get state => _state;

  /// Whether the session is actively scanning.
  bool get isActive => _state == SessionState.active;

  /// Whether the session is paused.
  bool get isPaused => _state == SessionState.paused;

  /// Whether the session has completed.
  bool get isCompleted =>
      _state == SessionState.completed || _state == SessionState.cancelled;

  /// Unmodifiable list of scan results collected in this session.
  List<ScanResult> get results => List.unmodifiable(_results);

  /// Number of items in this session.
  int get itemCount => _results.length;

  /// Whether the session has reached its maximum capacity.
  bool get isFull => maxItems != null && _results.length >= maxItems!;

  /// Stream of new scan results added to this session.
  Stream<ScanResult> get resultStream => _resultStreamController.stream;

  /// Stream of session state changes.
  Stream<SessionState> get stateStream => _stateStreamController.stream;

  /// Starts or resumes the scanning session.
  void start() {
    if (_state == SessionState.completed || _state == SessionState.cancelled) {
      return; // Cannot restart completed/cancelled sessions
    }

    _startedAt ??= DateTime.now();
    _setState(SessionState.active);
  }

  /// Pauses the scanning session temporarily.
  void pause() {
    if (_state != SessionState.active) return;
    _setState(SessionState.paused);
  }

  /// Resumes the scanning session from paused state.
  void resume() {
    if (_state != SessionState.paused) return;
    _setState(SessionState.active);
  }

  /// Completes the scanning session.
  void complete() {
    if (_state == SessionState.completed || _state == SessionState.cancelled) {
      return;
    }
    _endedAt = DateTime.now();
    _setState(SessionState.completed);
  }

  /// Cancels the scanning session.
  void cancel() {
    _endedAt = DateTime.now();
    _setState(SessionState.cancelled);
  }

  /// Adds a scan result to the session.
  ///
  /// Returns `true` if the result was added, `false` if it was filtered (duplicate or capacity).
  bool addResult(ScanResult result) {
    if (_state != SessionState.active) return false;
    if (isFull) return false;

    // Duplicate detection
    if (enableDuplicateFilter) {
      final normalizedValue = result.rawValue.trim().toLowerCase();
      if (_seenValues.contains(normalizedValue)) {
        _duplicatesFiltered++;
        notifyListeners();
        return false;
      }
      _seenValues.add(normalizedValue);
    }

    // Add session metadata to result
    final enrichedResult = result.copyWith(
      metadata: {
        ...result.metadata,
        'sessionId': sessionId,
        'sessionIndex': _results.length,
      },
    );

    _results.add(enrichedResult);
    _scanTimestamps.add(DateTime.now());

    if (!_resultStreamController.isClosed) {
      _resultStreamController.add(enrichedResult);
    }

    notifyListeners();
    return true;
  }

  /// Removes a result at the specified index.
  void removeAt(int index) {
    if (index >= 0 && index < _results.length) {
      final removed = _results.removeAt(index);
      _seenValues.remove(removed.rawValue.trim().toLowerCase());
      notifyListeners();
    }
  }

  /// Clears all results from the session (resets but keeps session active).
  void clearResults() {
    _results.clear();
    _seenValues.clear();
    _duplicatesFiltered = 0;
    _scanTimestamps.clear();
    notifyListeners();
  }

  /// Gets current session statistics.
  SessionStats getStats() {
    final now = DateTime.now();
    final duration = _startedAt != null
        ? (_endedAt ?? now).difference(_startedAt!)
        : Duration.zero;

    final validCount = _results.where((r) => r.isValid).length;
    final invalidCount = _results.where((r) => !r.isValid).length;

    Duration? avgInterval;
    if (_scanTimestamps.length >= 2) {
      final totalInterval = _scanTimestamps.last
          .difference(_scanTimestamps.first)
          .inMilliseconds;
      avgInterval = Duration(
          milliseconds: totalInterval ~/ (_scanTimestamps.length - 1));
    }

    // Find dominant mode
    ScanMode? dominant;
    if (_results.isNotEmpty) {
      final modeCounts = <ScanMode, int>{};
      for (final result in _results) {
        modeCounts[result.mode] = (modeCounts[result.mode] ?? 0) + 1;
      }
      dominant = modeCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    return SessionStats(
      totalScans: _results.length,
      validScans: validCount,
      invalidScans: invalidCount,
      duplicatesFiltered: _duplicatesFiltered,
      startedAt: _startedAt ?? now,
      endedAt: _endedAt,
      duration: duration,
      successRate:
          _results.isNotEmpty ? validCount / _results.length : 0.0,
      averageScanInterval: avgInterval,
      dominantMode: dominant,
    );
  }

  /// Filters session results by scan mode.
  List<ScanResult> filterByMode(ScanMode mode) {
    return _results.where((r) => r.mode == mode).toList();
  }

  /// Searches session results by query string.
  List<ScanResult> search(String query) {
    final term = query.toLowerCase();
    return _results.where((r) {
      if (r.rawValue.toLowerCase().contains(term)) return true;
      return r.fields.values.any((v) => v.toLowerCase().contains(term));
    }).toList();
  }

  /// Exports session results as JSON string.
  String exportToJson({bool pretty = true}) {
    return JsonExporter.exportToJson(_results, prettyPrint: pretty);
  }

  /// Exports session results as CSV string.
  String exportToCsv() {
    return CsvExporter.exportToCsv(_results);
  }

  /// Exports session results as PDF byte buffer.
  Uint8List exportToPdf({String? title}) {
    return PdfExporter.exportResultsToPdf(
      results: _results,
      title: title ?? 'Scan Session: ${name ?? sessionId}',
    );
  }

  void _setState(SessionState newState) {
    _state = newState;
    if (!_stateStreamController.isClosed) {
      _stateStreamController.add(newState);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _resultStreamController.close();
    _stateStreamController.close();
    super.dispose();
  }
}
