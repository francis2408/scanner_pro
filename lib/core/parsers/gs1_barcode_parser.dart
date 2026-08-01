import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Dynamic GS1 Application Identifier (AI) & Custom Barcode Payload Parser
class Gs1BarcodeParser {
  static const Map<String, String> _aiNames = {
    '00': 'SSCC Container Code',
    '01': 'GTIN (Product Code)',
    '02': 'Content GTIN',
    '10': 'Batch/Lot Number',
    '11': 'Production Date',
    '12': 'Due Date',
    '13': 'Packaging Date',
    '15': 'Best Before Date',
    '17': 'Expiry Date',
    '20': 'Variant Number',
    '21': 'Serial Number',
    '22': 'HIBCC Secondary Data',
    '30': 'Quantity',
    '37': 'Unit Count',
    '240': 'Additional Item ID',
    '400': 'Customer Purchase Order',
    '414': 'GLN Location Number',
    '8004': 'GIAI Asset ID',
  };

  /// Parse GS1 payload or dynamic text into a structured ScanResult
  static ScanResult parse(String rawValue) {
    final fields = parseGs1Payload(rawValue);

    final isValid = fields.isNotEmpty;

    return ScanResult(
      mode: ScanMode.barcode,
      rawValue: rawValue,
      isValid: isValid,
      confidence: isValid ? 0.99 : 0.70,
      fields: fields,
      metadata: {
        'format': 'Dynamic Barcode Parser Engine',
        'fieldsExtracted': fields.length.toString(),
      },
    );
  }

  /// Dynamically parses GS1 AIs, key-value pairs, and heuristic patterns
  static Map<String, String> parseGs1Payload(String rawValue) {
    final Map<String, String> fields = {};
    String text = rawValue.trim();

    // Remove GS1 FNC1 prefix (e.g. ]C1, ]e0, ]d2)
    if (text.startsWith(']')) {
      text = text.substring(3);
    }

    // 1. Try parenthesized pattern: (01)00012345678905(17)20281231(10)LOT4587(30)24
    final parenMatches = RegExp(r'\((\d{2,4})\)([^\(\)]+)').allMatches(text);
    if (parenMatches.isNotEmpty) {
      for (final m in parenMatches) {
        final ai = m.group(1)!;
        final val = m.group(2)!.trim();
        _processAi(fields, ai, val);
      }
      if (fields.isNotEmpty) {
        _applyDynamicHeuristics(text, fields);
        return fields;
      }
    }

    // 2. Try Key-Value structured lines (e.g. "GTIN: 000123...", "Expiry: 2028-12-31", "Batch=LOT4587")
    _parseKeyValueLines(text, fields);

    // 3. Unparenthesized GS1 AI stream parsing (e.g. 01000123456789051728123110LOT45873024)
    final cleanText = text.replaceAll(RegExp(r'[\x1D\u001D\x1E]'), '|');
    _parseUnparenthesizedGs1(cleanText, fields);

    // 4. Dynamic Heuristic Extraction (extracts GTIN, Expiry Date, Lot, Quantity from ANY raw text)
    _applyDynamicHeuristics(text, fields);

    return fields;
  }

  static void _parseKeyValueLines(String text, Map<String, String> fields) {
    final lines = text.split(RegExp(r'[\r\n;,|]+'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Key: Value or Key = Value or Key - Value
      final kvMatch = RegExp(
        r'^([A-Za-z0-9\s_\-\.]{2,30})[:=](.+)$',
      ).firstMatch(trimmed);
      if (kvMatch != null) {
        final key = kvMatch.group(1)!.trim();
        final val = kvMatch.group(2)!.trim();
        if (key.isNotEmpty && val.isNotEmpty && !fields.containsKey(key)) {
          fields[key] = val;
        }
      }
    }
  }

  static void _parseUnparenthesizedGs1(
    String text,
    Map<String, String> fields,
  ) {
    int idx = 0;
    while (idx < text.length) {
      if (text[idx] == '|') {
        idx++;
        continue;
      }

      // Check AI 01 (GTIN - 14 digits)
      if (idx + 16 <= text.length && text.startsWith('01', idx)) {
        final gtin = text.substring(idx + 2, idx + 16);
        if (RegExp(r'^\d{14}$').hasMatch(gtin)) {
          fields.putIfAbsent('GTIN (Product Code)', () => gtin);
          idx += 16;
          continue;
        }
      }

      // Check AI 17 (Expiry Date - 6 digits YYMMDD or 8 digits YYYYMMDD)
      if (idx + 8 <= text.length && text.startsWith('17', idx)) {
        final dateCandidate = text.substring(idx + 2, idx + 8);
        if (RegExp(r'^\d{6}$').hasMatch(dateCandidate)) {
          fields.putIfAbsent('Expiry Date', () => _formatYYMMDD(dateCandidate));
          idx += 8;
          continue;
        }
      }

      // Check AI 11 (Production Date - 6 digits YYMMDD)
      if (idx + 8 <= text.length && text.startsWith('11', idx)) {
        final dateCandidate = text.substring(idx + 2, idx + 8);
        if (RegExp(r'^\d{6}$').hasMatch(dateCandidate)) {
          fields.putIfAbsent(
            'Production Date',
            () => _formatYYMMDD(dateCandidate),
          );
          idx += 8;
          continue;
        }
      }

      // Check AI 10 (Batch/Lot Number)
      if (text.startsWith('10', idx)) {
        final sub = text.substring(idx + 2);
        final delimIdx = sub.indexOf('|');
        final nextAiIdx = _findNextAiIndex(sub);
        final endIdx = delimIdx != -1
            ? delimIdx
            : (nextAiIdx != -1 ? nextAiIdx : sub.length);
        final lot = sub.substring(0, endIdx);
        if (lot.isNotEmpty) {
          fields.putIfAbsent('Batch/Lot Number', () => lot);
          idx += 2 + endIdx;
          continue;
        }
      }

      // Check AI 30 (Quantity)
      if (text.startsWith('30', idx)) {
        final sub = text.substring(idx + 2);
        final match = RegExp(r'^\d+').firstMatch(sub);
        if (match != null) {
          final qty = match.group(0)!;
          fields.putIfAbsent('Quantity', () => qty);
          idx += 2 + qty.length;
          continue;
        }
      }

      // Check AI 21 (Serial Number)
      if (text.startsWith('21', idx)) {
        final sub = text.substring(idx + 2);
        final delimIdx = sub.indexOf('|');
        final nextAiIdx = _findNextAiIndex(sub);
        final endIdx = delimIdx != -1
            ? delimIdx
            : (nextAiIdx != -1 ? nextAiIdx : sub.length);
        final serial = sub.substring(0, endIdx);
        if (serial.isNotEmpty) {
          fields.putIfAbsent('Serial Number', () => serial);
          idx += 2 + endIdx;
          continue;
        }
      }

      idx++;
    }
  }

  static void _applyDynamicHeuristics(
    String rawText,
    Map<String, String> fields,
  ) {
    // 1. Dynamic GTIN/EAN 13 or 14-digit pattern
    if (!fields.containsKey('GTIN (Product Code)')) {
      final gtinMatch = RegExp(r'\b\d{13,14}\b').firstMatch(rawText);
      if (gtinMatch != null) {
        fields['GTIN (Product Code)'] = gtinMatch.group(0)!;
      }
    }

    // 2. Dynamic Expiry Date pattern (YYYY-MM-DD, DD/MM/YYYY, EXP: YYYYMMDD)
    if (!fields.containsKey('Expiry Date')) {
      final expMatch = RegExp(
        r'(?:EXP|EXPIRY|BEST BEFORE|USE BY)[:\s]*(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4}|\d{6}|\d{8})',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (expMatch != null) {
        fields['Expiry Date'] = _formatYYMMDD(expMatch.group(1)!);
      } else {
        // Fallback: standalone ISO date
        final isoDateMatch = RegExp(
          r'\b20[2-9]\d[-/](?:0[1-9]|1[0-2])[-/](?:0[1-9]|[12]\d|3[01])\b',
        ).firstMatch(rawText);
        if (isoDateMatch != null) {
          fields['Expiry Date'] = isoDateMatch.group(0)!;
        }
      }
    }

    // 3. Dynamic Batch / Lot Number pattern (LOT1234, BATCH: ABC, BN: 9988)
    if (!fields.containsKey('Batch/Lot Number')) {
      final lotMatch = RegExp(
        r'(?:LOT|BATCH|B\.NO|BN)[:\s\-]*([A-Z0-9\-_]{3,20})',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (lotMatch != null) {
        fields['Batch/Lot Number'] = lotMatch.group(1)!;
      }
    }

    // 4. Dynamic Quantity / Count pattern (QTY: 24, 24 PCS, COUNT=10)
    if (!fields.containsKey('Quantity')) {
      final qtyMatch = RegExp(
        r'(?:QTY|QUANTITY|COUNT|PCS)[:\s]*(\d+)',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (qtyMatch != null) {
        fields['Quantity'] = qtyMatch.group(1)!;
      }
    }

    // 5. Dynamic Serial Number pattern (SN: 12345, SER: ABC)
    if (!fields.containsKey('Serial Number')) {
      final serialMatch = RegExp(
        r'(?:SN|SER|SERIAL|S/N)[:\s\-]*([A-Z0-9\-_]{4,25})',
        caseSensitive: false,
      ).firstMatch(rawText);
      if (serialMatch != null) {
        fields['Serial Number'] = serialMatch.group(1)!;
      }
    }
  }

  static int _findNextAiIndex(String text) {
    final matches = [
      text.indexOf('17'),
      text.indexOf('10'),
      text.indexOf('30'),
      text.indexOf('21'),
    ].where((i) => i > 0).toList();

    if (matches.isEmpty) return -1;
    matches.sort();
    return matches.first;
  }

  static void _processAi(Map<String, String> fields, String ai, String val) {
    switch (ai) {
      case '01':
      case '02':
        fields['GTIN (Product Code)'] = val;
        break;
      case '17':
        fields['Expiry Date'] = _formatYYMMDD(val);
        break;
      case '11':
        fields['Production Date'] = _formatYYMMDD(val);
        break;
      case '13':
        fields['Packaging Date'] = _formatYYMMDD(val);
        break;
      case '15':
        fields['Best Before Date'] = _formatYYMMDD(val);
        break;
      case '10':
        fields['Batch/Lot Number'] = val;
        break;
      case '21':
        fields['Serial Number'] = val;
        break;
      case '30':
        fields['Quantity'] = val;
        break;
      default:
        final name = _aiNames[ai] ?? 'AI ($ai)';
        fields[name] = val;
        break;
    }
  }

  static String _formatYYMMDD(String yymmdd) {
    if (yymmdd.contains('-') || yymmdd.contains('/')) return yymmdd;
    if (yymmdd.length == 8 && RegExp(r'^\d{8}$').hasMatch(yymmdd)) {
      return '${yymmdd.substring(0, 4)}-${yymmdd.substring(4, 6)}-${yymmdd.substring(6, 8)}';
    }
    if (yymmdd.length != 6) return yymmdd;
    final yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);
    final year = yy > 50 ? 1900 + yy : 2000 + yy;
    return '$year-$mm-$dd';
  }
}
