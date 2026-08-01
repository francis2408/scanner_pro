import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Indian Income Tax PAN (Permanent Account Number) Card parser & fuzzy OCR engine.
class PanCardParser {
  static const Map<String, String> _holderStatusMap = {
    'P': 'Individual / Person',
    'C': 'Company',
    'H': 'Hindu Undivided Family (HUF)',
    'F': 'Firm / Partnership',
    'A': 'Association of Persons (AOP)',
    'T': 'Trust',
    'B': 'Body of Individuals (BOI)',
    'L': 'Local Authority',
    'J': 'Artificial Juridical Person',
  };

  /// Decodes 4th character status code to Taxpayer Category name.
  static String getCategoryName(String statusChar) {
    return _holderStatusMap[statusChar.toUpperCase()] ??
        'Taxpayer Category ($statusChar)';
  }

  static String? _extractPanCandidate(String uppercaseText) {
    final panRegex = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]{1}\b');
    Match? match = panRegex.firstMatch(uppercaseText);
    if (match != null) return match.group(0);

    final lines = uppercaseText.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      final cleanLine = line.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (cleanLine.length >= 10) {
        for (int i = 0; i <= cleanLine.length - 10; i++) {
          final window = cleanLine.substring(i, i + 10);
          final chars = window.split('');

          bool isValid5 = true;
          for (int c = 0; c < 5; c++) {
            if (chars[c] == '0') chars[c] = 'O';
            if (chars[c] == '1') chars[c] = 'I';
            if (chars[c] == '5') chars[c] = 'S';
            if (chars[c] == '8') chars[c] = 'B';
            if (!RegExp(r'^[A-Z]$').hasMatch(chars[c])) {
              isValid5 = false;
              break;
            }
          }
          if (!isValid5) continue;

          bool isValid4 = true;
          for (int c = 5; c < 9; c++) {
            if (chars[c] == 'O' || chars[c] == 'Q') chars[c] = '0';
            if (chars[c] == 'I' || chars[c] == 'L') chars[c] = '1';
            if (chars[c] == 'S') chars[c] = '5';
            if (chars[c] == 'B') chars[c] = '8';
            if (!RegExp(r'^[0-9]$').hasMatch(chars[c])) {
              isValid4 = false;
              break;
            }
          }
          if (!isValid4) continue;

          if (chars[9] == '0') chars[9] = 'O';
          if (chars[9] == '1') chars[9] = 'I';
          if (!RegExp(r'^[A-Z]$').hasMatch(chars[9])) continue;

          final candidate = chars.join('');
          if (panRegex.hasMatch(candidate)) {
            return candidate;
          }
        }
      }
    }
    return null;
  }

  /// Parses raw text input into a structured PAN card [ScanResult].
  static ScanResult parse(String rawText) {
    final uppercaseText = rawText.toUpperCase();
    final foundPan = _extractPanCandidate(uppercaseText);

    if (foundPan != null) {
      final panNumber = foundPan;
      final statusChar = panNumber[3];
      final holderStatus =
          _holderStatusMap[statusChar] ?? 'Taxpayer Category ($statusChar)';

      final Map<String, String> fields = {
        'Document Type': 'Income Tax PAN Card (India)',
        'PAN Number': panNumber,
        'Holder Category': holderStatus,
        'Surname Initial': panNumber[4],
      };

      final lines = rawText
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .toList();

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (RegExp(r'\b\d{2}/\d{2}/\d{4}\b').hasMatch(line)) {
          final dobMatch = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(line);
          if (dobMatch != null) fields['Date of Birth'] = dobMatch.group(0)!;
        } else if (line.contains('GOVT OF INDIA') ||
            line.contains('INCOME TAX') ||
            line.contains('PERMANENT ACCOUNT')) {
          continue;
        } else if (i < lines.length &&
            !line.contains(panNumber) &&
            line.length >= 3 &&
            RegExp(r'^[A-Z\s]+$').hasMatch(line)) {
          if (!fields.containsKey('Holder Name')) {
            fields['Holder Name'] = line;
          } else if (!fields.containsKey("Father's Name")) {
            fields["Father's Name"] = line;
          }
        }
      }

      return ScanResult(
        mode: ScanMode.pan,
        rawValue: rawText,
        isValid: true,
        confidence: 0.96,
        fields: fields,
        metadata: {'panNumber': panNumber, 'statusChar': statusChar},
      );
    }

    return ScanResult(
      mode: ScanMode.pan,
      rawValue: rawText,
      isValid: false,
      confidence: 0.35,
      fields: {'Document Type': 'PAN Card (Unparsed)', 'Raw Text': rawText},
    );
  }
}
