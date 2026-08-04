import 'dart:convert';
import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

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

  /// Parses a JSON string back into a list of [ScanResult] items.
  static List<ScanResult> importFromJson(String jsonString) {
    if (jsonString.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonString);
      List<dynamic> items = [];

      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('scanSession') &&
            decoded['scanSession'] is Map &&
            (decoded['scanSession'] as Map).containsKey('items')) {
          items = (decoded['scanSession'] as Map)['items'] as List<dynamic>;
        } else if (decoded.containsKey('items') && decoded['items'] is List) {
          items = decoded['items'] as List<dynamic>;
        } else if (decoded.containsKey('batch') && decoded['batch'] is List) {
          items = decoded['batch'] as List<dynamic>;
        }
      }

      return items
          .map((item) => _fromJsonMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static ScanResult _fromJsonMap(Map<String, dynamic> json) {
    final modeStr = json['mode'] as String? ?? 'qr';
    final mode = _parseMode(modeStr);

    final fieldsRaw = json['fields'] as Map<String, dynamic>?;
    final fields = fieldsRaw?.map((k, v) => MapEntry(k, v.toString())) ??
        const <String, String>{};

    return ScanResult(
      mode: mode,
      rawValue: json['rawValue'] as String? ?? '',
      fields: fields,
      isValid: json['isValid'] as bool? ?? true,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      format: json['format'] as String?,
      documentCategory: json['documentCategory'] as String?,
      isDuplicate: json['isDuplicate'] as bool? ?? false,
    );
  }

  static ScanMode _parseMode(String name) {
    return ScanMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ScanMode.qr,
    );
  }
}
