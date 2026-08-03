import 'dart:convert';
import '../models/scan_result.dart';

/// Serializes batch scan results or history logs into structured JSON format.
class JsonExporter {
  /// Exports list of [ScanResult] items to formatted JSON string.
  static String exportToJson(
    List<ScanResult> results, {
    bool prettyPrint = true,
  }) {
    final list = results.map((r) => r.toJson()).toList();
    if (prettyPrint) {
      return const JsonEncoder.withIndent('  ').convert({
        'scanSession': {
          'exportedAt': DateTime.now().toIso8601String(),
          'totalItems': results.length,
          'items': list,
        }
      });
    }
    return jsonEncode(list);
  }
}
