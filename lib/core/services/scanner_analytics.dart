import '../models/scan_result.dart';

/// Tracks enterprise session metrics, success rates, scan latency averages,
/// and failure analytics across scanning operations.
class ScannerAnalytics {
  int _totalScans = 0;
  int _successfulScans = 0;
  int _failedScans = 0;
  int _duplicateScans = 0;
  final List<Duration> _scanDurations = [];
  final Map<String, int> _scansByMode = {};
  final Map<String, int> _scansByFormat = {};

  /// Total number of scan attempts recorded in this session.
  int get totalScans => _totalScans;

  /// Total number of valid successful scans.
  int get successfulScans => _successfulScans;

  /// Total number of failed or invalid scan attempts.
  int get failedScans => _failedScans;

  /// Total number of filtered duplicate scans.
  int get duplicateScans => _duplicateScans;

  /// Percentage success rate (0.0 to 100.0%).
  double get successRate =>
      _totalScans > 0 ? (_successfulScans / _totalScans) * 100.0 : 0.0;

  /// Percentage failure rate (0.0 to 100.0%).
  double get failureRate =>
      _totalScans > 0 ? (_failedScans / _totalScans) * 100.0 : 0.0;

  /// Average scan processing duration in milliseconds.
  double get averageScanDurationMs {
    if (_scanDurations.isEmpty) return 0.0;
    final totalMs = _scanDurations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    return totalMs / _scanDurations.length;
  }

  /// Map of scan counts grouped by [ScanMode] name.
  Map<String, int> get scansByMode => Map.unmodifiable(_scansByMode);

  /// Map of scan counts grouped by barcode or document format string.
  Map<String, int> get scansByFormat => Map.unmodifiable(_scansByFormat);

  /// Records a scan operation event.
  void recordScan(ScanResult result) {
    _totalScans++;
    final modeKey = result.mode.name;
    _scansByMode[modeKey] = (_scansByMode[modeKey] ?? 0) + 1;

    if (result.format != null && result.format!.isNotEmpty) {
      _scansByFormat[result.format!] =
          (_scansByFormat[result.format!] ?? 0) + 1;
    }

    if (result.isDuplicate) {
      _duplicateScans++;
    }

    if (result.isValid) {
      _successfulScans++;
      if (result.scanDuration != null) {
        _scanDurations.add(result.scanDuration!);
        if (_scanDurations.length > 500) {
          _scanDurations.removeAt(0);
        }
      }
    } else {
      _failedScans++;
    }
  }

  /// Resets all analytics session metrics back to zero.
  void reset() {
    _totalScans = 0;
    _successfulScans = 0;
    _failedScans = 0;
    _duplicateScans = 0;
    _scanDurations.clear();
    _scansByMode.clear();
    _scansByFormat.clear();
  }

  /// Converts analytics summary metrics to a readable string or json.
  Map<String, dynamic> toJson() {
    return {
      'totalScans': _totalScans,
      'successfulScans': _successfulScans,
      'failedScans': _failedScans,
      'duplicateScans': _duplicateScans,
      'successRatePercent': double.parse(successRate.toStringAsFixed(2)),
      'failureRatePercent': double.parse(failureRate.toStringAsFixed(2)),
      'averageScanDurationMs':
          double.parse(averageScanDurationMs.toStringAsFixed(2)),
      'scansByMode': _scansByMode,
      'scansByFormat': _scansByFormat,
    };
  }
}
