import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

class AadhaarParser {
  static const List<List<int>> _d = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];

  static const List<List<int>> _p = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];

  static bool validateAadhaarVerhoeff(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.length != 12 || !RegExp(r'^[2-9]\d{11}$').hasMatch(clean)) {
      return false;
    }
    int c = 0;
    final reversedDigits = clean
        .split('')
        .map(int.parse)
        .toList()
        .reversed
        .toList();
    for (int i = 0; i < reversedDigits.length; i++) {
      c = _d[c][_p[i % 8][reversedDigits[i]]];
    }
    return c == 0;
  }

  static ScanResult parse(String rawData) {
    if (rawData.contains('<?xml') ||
        rawData.contains('<PrintLetterBarcodeData')) {
      return _parseXmlQr(rawData);
    }

    final uidRegex = RegExp(r'\b[2-9]\d{3}\s?\d{4}\s?\d{4}\b');
    final uidMatch = uidRegex.firstMatch(rawData);

    if (uidMatch != null) {
      final rawUid = uidMatch.group(0)!;
      final cleanUid = rawUid.replaceAll(' ', '');
      final isVerhoeffValid = validateAadhaarVerhoeff(cleanUid);

      final Map<String, String> fields = {
        'Card Type': 'Aadhaar Card (India)',
        'Aadhaar Number':
            '${cleanUid.substring(0, 4)} ${cleanUid.substring(4, 8)} ${cleanUid.substring(8, 12)}',
        'Verhoeff Checksum': isVerhoeffValid ? 'Valid ✓' : 'Invalid ✗',
      };

      final lines = rawData
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .toList();
      for (final line in lines) {
        if (RegExp(r'DOB|Date of Birth', caseSensitive: false).hasMatch(line)) {
          final dobMatch = RegExp(r'\d{2}/\d{2}/\d{4}').firstMatch(line);
          if (dobMatch != null) fields['Date of Birth'] = dobMatch.group(0)!;
        } else if (RegExp(
          r'Year of Birth|YOB',
          caseSensitive: false,
        ).hasMatch(line)) {
          final yobMatch = RegExp(r'\d{4}').firstMatch(line);
          if (yobMatch != null) fields['Year of Birth'] = yobMatch.group(0)!;
        } else if (RegExp(
          r'\bMale\b|\bFemale\b|\bTRANSGENDER\b',
          caseSensitive: false,
        ).hasMatch(line)) {
          fields['Gender'] = line;
        }
      }

      return ScanResult(
        mode: ScanMode.aadhaar,
        rawValue: rawData,
        isValid: isVerhoeffValid,
        confidence: isVerhoeffValid ? 0.95 : 0.70,
        fields: fields,
      );
    }

    return ScanResult(
      mode: ScanMode.aadhaar,
      rawValue: rawData,
      isValid: false,
      confidence: 0.3,
      fields: {'Card Type': 'Aadhaar (Unparsed)', 'Raw Input': rawData},
    );
  }

  static ScanResult _parseXmlQr(String xmlStr) {
    final fields = <String, String>{'Card Type': 'Aadhaar Secure QR XML'};

    final attrRegex = RegExp(r'(\w+)="([^"]*)"');
    final matches = attrRegex.allMatches(xmlStr);

    for (final m in matches) {
      final key = m.group(1)!;
      final val = m.group(2)!;
      switch (key) {
        case 'uid':
          fields['Aadhaar Number'] = val;
          break;
        case 'name':
          fields['Full Name'] = val;
          break;
        case 'gender':
          fields['Gender'] = val == 'M'
              ? 'Male'
              : (val == 'F' ? 'Female' : val);
          break;
        case 'dob':
          fields['Date of Birth'] = val;
          break;
        case 'yob':
          fields['Year of Birth'] = val;
          break;
        case 'co':
          fields['C/O'] = val;
          break;
        case 'house':
        case 'street':
        case 'loc':
        case 'vtc':
        case 'po':
        case 'dist':
        case 'state':
        case 'pc':
          fields[key.toUpperCase()] = val;
          break;
      }
    }

    final uid = fields['Aadhaar Number'] ?? '';
    final isValid = uid.isNotEmpty ? validateAadhaarVerhoeff(uid) : true;

    return ScanResult(
      mode: ScanMode.aadhaar,
      rawValue: xmlStr,
      isValid: isValid,
      confidence: 0.98,
      fields: fields,
    );
  }
}
