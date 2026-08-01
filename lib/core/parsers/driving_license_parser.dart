import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// AAMVA PDF417 and Regional Driving License OCR parser.
class DrivingLicenseParser {
  /// Parses raw PDF417 or OCR text input from a Driving License.
  static ScanResult parse(String rawText) {
    if (rawText.contains('@') || rawText.contains('ANSI ') || rawText.contains('AAMVA')) {
      return _parseAamvaPdf417(rawText);
    }
    return _parseDlOcr(rawText);
  }

  static ScanResult _parseAamvaPdf417(String rawText) {
    final fields = <String, String>{
      'Document Standard': 'AAMVA Driver License (PDF417)',
    };

    final keys = ['DAQ', 'DCS', 'DAC', 'DAD', 'DCB', 'DCD', 'DBB', 'DBA', 'DBD', 'DBC', 'DAG', 'DAI', 'DAJ', 'DAK', 'DAR', 'DAS', 'DAT'];

    final lines = rawText.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      for (final key in keys) {
        final idx = line.indexOf(key);
        if (idx != -1 && (idx + key.length < line.length)) {
          final val = line.substring(idx + key.length).trim();
          _assignAamvaField(fields, key, val);
        }
      }
    }

    final hasDlNum = fields.containsKey('License Number');

    return ScanResult(
      mode: ScanMode.drivingLicense,
      rawValue: rawText,
      isValid: hasDlNum,
      confidence: hasDlNum ? 0.98 : 0.80,
      fields: fields,
    );
  }

  static void _assignAamvaField(Map<String, String> fields, String code, String value) {
    String cleanVal = value;
    if (cleanVal.length > 25) cleanVal = cleanVal.substring(0, 25);

    switch (code) {
      case 'DAQ':
        fields['License Number'] = cleanVal;
        break;
      case 'DCS':
      case 'DCA':
        fields['Last Name'] = cleanVal;
        break;
      case 'DAC':
      case 'DCB':
        fields['First Name'] = cleanVal;
        break;
      case 'DAD':
      case 'DCD':
        fields['Middle Name'] = cleanVal;
        break;
      case 'DBB':
        fields['Date of Birth'] = _formatAamvaDate(cleanVal);
        break;
      case 'DBA':
        fields['Expiration Date'] = _formatAamvaDate(cleanVal);
        break;
      case 'DBD':
        fields['Issue Date'] = _formatAamvaDate(cleanVal);
        break;
      case 'DBC':
        fields['Sex'] = cleanVal == '1' ? 'Male' : (cleanVal == '2' ? 'Female' : cleanVal);
        break;
      case 'DAG':
        fields['Address'] = cleanVal;
        break;
      case 'DAI':
        fields['City'] = cleanVal;
        break;
      case 'DAJ':
        fields['State'] = cleanVal;
        break;
      case 'DAK':
        fields['Zip Code'] = cleanVal;
        break;
    }
  }

  static ScanResult _parseDlOcr(String rawText) {
    final dlRegex = RegExp(r'\b[A-Z]{2}[-\s/]?\d{2}[-\s/]?\d{4}[-\s/]?\d{7}\b|\b[A-Z]{2}\d{13}\b', caseSensitive: false);
    final match = dlRegex.firstMatch(rawText);

    final fields = <String, String>{
      'Document Type': 'Driving License (OCR)',
    };

    if (match != null) {
      fields['DL Number'] = match.group(0)!;
    }

    final dateRegex = RegExp(r'\b\d{2}[/-]\d{2}[/-]\d{4}\b|\b\d{4}[/-]\d{2}[/-]\d{2}\b');
    final dateMatches = dateRegex.allMatches(rawText).map((m) => m.group(0)!).toList();

    if (dateMatches.isNotEmpty) fields['Date of Birth / Issue'] = dateMatches.first;
    if (dateMatches.length > 1) fields['Expiration Date'] = dateMatches.last;

    final lines = rawText.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).toList();
    for (final line in lines) {
      if (line.contains('Name') || line.contains('NAME')) {
        final parts = line.split(':');
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          fields['Holder Name'] = parts[1].trim();
        }
      }
    }

    final isValid = fields.containsKey('DL Number');

    return ScanResult(
      mode: ScanMode.drivingLicense,
      rawValue: rawText,
      isValid: isValid,
      confidence: isValid ? 0.92 : 0.45,
      fields: fields,
    );
  }

  static String _formatAamvaDate(String str) {
    if (str.length >= 8) {
      final sub = str.substring(0, 8);
      if (int.tryParse(sub.substring(0, 2)) != null && int.parse(sub.substring(0, 2)) <= 12) {
        return '${sub.substring(4, 8)}-${sub.substring(0, 2)}-${sub.substring(2, 4)}';
      }
      return '${sub.substring(0, 4)}-${sub.substring(4, 6)}-${sub.substring(6, 8)}';
    }
    return str;
  }
}
