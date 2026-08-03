import '../models/scan_result.dart';

/// Exports lists of [ScanResult] items to RFC 4180 compliant CSV text format
/// suitable for warehouse inventory, ERP systems, and spreadsheet analysis.
class CsvExporter {
  /// Converts a list of scan results into a formatted CSV string.
  static String exportToCsv(
    List<ScanResult> results, {
    bool includeHeaders = true,
    String delimiter = ',',
  }) {
    final buffer = StringBuffer();

    if (includeHeaders) {
      buffer.writeln([
        'Index',
        'Timestamp',
        'Mode',
        'Format',
        'Raw Value',
        'Confidence',
        'Is Valid',
        'Parsed Fields',
      ].map(_escapeCsvValue).join(delimiter));
    }

    for (int i = 0; i < results.length; i++) {
      final res = results[i];
      final fieldsSummary = res.fields.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' | ');

      final row = [
        (i + 1).toString(),
        res.timestamp.toIso8601String(),
        res.mode.name,
        res.format ?? 'N/A',
        res.rawValue,
        '${(res.confidence * 100).toStringAsFixed(1)}%',
        res.isValid ? 'YES' : 'NO',
        fieldsSummary,
      ];

      buffer.writeln(row.map(_escapeCsvValue).join(delimiter));
    }

    return buffer.toString();
  }

  static String _escapeCsvValue(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
