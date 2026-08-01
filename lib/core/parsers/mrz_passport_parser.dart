import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

class MrzPassportParser {
  static int _getCharWeight(String char) {
    if (char == '<') return 0;
    final code = char.codeUnitAt(0);
    if (code >= 48 && code <= 57) {
      return code - 48;
    }
    if (code >= 65 && code <= 90) {
      return code - 55;
    }
    return 0;
  }

  static int calculateCheckDigit(String input) {
    final weights = [7, 3, 1];
    int sum = 0;
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final weight = weights[i % 3];
      sum += _getCharWeight(char) * weight;
    }
    return sum % 10;
  }

  static bool verifyCheckDigit(String data, String checkDigitChar) {
    if (checkDigitChar.isEmpty) return false;
    final expected = calculateCheckDigit(data);
    final actual = int.tryParse(checkDigitChar);
    return expected == actual;
  }

  static String formatDate(String yymmdd, {bool isExpiry = false}) {
    if (yymmdd.length != 6) return yymmdd;
    final yy = int.tryParse(yymmdd.substring(0, 2)) ?? 0;
    final mm = yymmdd.substring(2, 4);
    final dd = yymmdd.substring(4, 6);

    final currentYearShort = DateTime.now().year % 100;
    int year;
    if (isExpiry) {
      year = 2000 + yy;
    } else {
      year = (yy > currentYearShort + 5) ? 1900 + yy : 2000 + yy;
    }
    return '$year-$mm-$dd';
  }

  static ScanResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim().replaceAll(' ', ''))
        .where((l) => l.contains('<') || l.length >= 30)
        .toList();

    if (lines.length >= 2 && lines[0].length >= 44 && lines[1].length >= 44) {
      return _parseTD3(lines[0], lines[1], rawText);
    } else if (lines.length >= 3 &&
        lines[0].length >= 30 &&
        lines[1].length >= 30 &&
        lines[2].length >= 30) {
      return _parseTD1(lines[0], lines[1], lines[2], rawText);
    }

    final mrzMatches = RegExp(
      r'P<[A-Z<]{42,}[\r\n]+[A-Z0-9<]{44}',
    ).firstMatch(rawText);
    if (mrzMatches != null) {
      final parts = mrzMatches.group(0)!.split(RegExp(r'[\r\n]+'));
      if (parts.length >= 2) {
        return _parseTD3(parts[0], parts[1], rawText);
      }
    }

    return ScanResult(
      mode: ScanMode.passport,
      rawValue: rawText,
      isValid: false,
      confidence: 0.4,
      fields: {'Document Type': 'Unknown / Partial MRZ', 'Raw Text': rawText},
    );
  }

  static ScanResult _parseTD3(String line1, String line2, String rawText) {
    final issuingState = line1.substring(2, 5).replaceAll('<', '');

    final nameSection = line1.substring(5);
    final nameParts = nameSection.split('<<');
    final surname = nameParts.isNotEmpty
        ? nameParts[0].replaceAll('<', ' ').trim()
        : '';
    final givenNames = nameParts.length > 1
        ? nameParts[1].replaceAll('<', ' ').trim()
        : '';

    final passportNum = line2.substring(0, 9).replaceAll('<', '');
    final passportCheck = line2.substring(9, 10);
    final nationality = line2.substring(10, 13).replaceAll('<', '');
    final dob = line2.substring(13, 19);
    final dobCheck = line2.substring(19, 20);
    final sex = line2.substring(20, 21) == 'M'
        ? 'Male'
        : line2.substring(20, 21) == 'F'
        ? 'Female'
        : 'Unspecified';
    final expiry = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final personalNum = line2.substring(28, 42).replaceAll('<', '');

    final isPassNumValid = verifyCheckDigit(
      line2.substring(0, 9),
      passportCheck,
    );
    final isDobValid = verifyCheckDigit(dob, dobCheck);
    final isExpiryValid = verifyCheckDigit(expiry, expiryCheck);

    final isValid = isPassNumValid && isDobValid && isExpiryValid;

    return ScanResult(
      mode: ScanMode.passport,
      rawValue: rawText,
      isValid: isValid,
      confidence: isValid ? 0.98 : 0.75,
      fields: {
        'Document Type': 'Passport (ICAO TD3)',
        'Issuing State': issuingState,
        'Surname': surname,
        'Given Names': givenNames,
        'Passport Number': passportNum,
        'Passport Num Check': isPassNumValid ? 'Valid ✓' : 'Invalid ✗',
        'Nationality': nationality,
        'Date of Birth': formatDate(dob),
        'DOB Check': isDobValid ? 'Valid ✓' : 'Invalid ✗',
        'Sex': sex,
        'Expiration Date': formatDate(expiry, isExpiry: true),
        'Expiry Check': isExpiryValid ? 'Valid ✓' : 'Invalid ✗',
        if (personalNum.isNotEmpty) 'Personal Number': personalNum,
      },
      metadata: {
        'issuingState': issuingState,
        'passportNum': passportNum,
        'dob': dob,
        'expiry': expiry,
      },
    );
  }

  static ScanResult _parseTD1(
    String line1,
    String line2,
    String line3,
    String rawText,
  ) {
    final issuingState = line1.substring(2, 5).replaceAll('<', '');
    final docNum = line1.substring(5, 14).replaceAll('<', '');

    final dob = line2.substring(0, 6);
    final sexChar = line2.substring(7, 8);
    final sex = sexChar == 'M'
        ? 'Male'
        : (sexChar == 'F' ? 'Female' : 'Unspecified');
    final expiry = line2.substring(8, 14);
    final nationality = line2.substring(15, 18).replaceAll('<', '');

    final nameParts = line3.split('<<');
    final surname = nameParts.isNotEmpty
        ? nameParts[0].replaceAll('<', ' ').trim()
        : '';
    final givenNames = nameParts.length > 1
        ? nameParts[1].replaceAll('<', ' ').trim()
        : '';

    return ScanResult(
      mode: ScanMode.passport,
      rawValue: rawText,
      isValid: true,
      confidence: 0.92,
      fields: {
        'Document Type': 'ID Card (ICAO TD1)',
        'Issuing State': issuingState,
        'Document Number': docNum,
        'Surname': surname,
        'Given Names': givenNames,
        'Nationality': nationality,
        'Date of Birth': formatDate(dob),
        'Sex': sex,
        'Expiration Date': formatDate(expiry, isExpiry: true),
      },
    );
  }
}
