import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

class VinParser {
  static const Map<String, int> _charValues = {
    'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8,
    'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9,
    'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9,
    '0': 0, '1': 1, '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
  };

  static const List<int> _positionWeights = [
    8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2
  ];

  static const Map<String, String> _wmiMap = {
    '1HG': 'Honda (USA)',
    '1FT': 'Ford Truck (USA)',
    '1FA': 'Ford Passenger (USA)',
    '1G1': 'Chevrolet (USA)',
    '1J4': 'Jeep (USA)',
    '2G1': 'Chevrolet (Canada)',
    '3VW': 'Volkswagen (Mexico)',
    'JHM': 'Honda (Japan)',
    'JH4': 'Acura (Japan)',
    'JT2': 'Toyota (Japan)',
    'JNK': 'Infiniti (Japan)',
    'JN1': 'Nissan (Japan)',
    'WBA': 'BMW (Germany)',
    'WBY': 'BMW i (Germany)',
    'WAU': 'Audi (Germany)',
    'WDD': 'Mercedes-Benz (Germany)',
    'WP0': 'Porsche (Germany)',
    'SAL': 'Land Rover (UK)',
    'SAJ': 'Jaguar (UK)',
    'VF1': 'Renault (France)',
    'ZFF': 'Ferrari (Italy)',
    'KNA': 'Kia (South Korea)',
    'KMH': 'Hyundai (South Korea)',
    'MA3': 'Maruti Suzuki (India)',
    'ME4': 'Mahindra (India)',
    'MBH': 'Nissan (India)',
  };

  static String calculateCheckDigit(String vin) {
    if (vin.length != 17) return '';
    int sum = 0;
    for (int i = 0; i < 17; i++) {
      final char = vin[i].toUpperCase();
      final val = _charValues[char] ?? 0;
      sum += val * _positionWeights[i];
    }
    final remainder = sum % 11;
    return remainder == 10 ? 'X' : remainder.toString();
  }

  static String decodeModelYear(String pos10) {
    final char = pos10.toUpperCase();
    const map = {
      'A': '1980 / 2010', 'B': '1981 / 2011', 'C': '1982 / 2012', 'D': '1983 / 2013',
      'E': '1984 / 2014', 'F': '1985 / 2015', 'G': '1986 / 2016', 'H': '1987 / 2017',
      'J': '1988 / 2018', 'K': '1989 / 2019', 'L': '1990 / 2020', 'M': '1991 / 2021',
      'N': '1992 / 2022', 'P': '1993 / 2023', 'R': '1994 / 2024', 'S': '1995 / 2025',
      'T': '1996 / 2026', 'V': '1997 / 2027', 'W': '1998 / 2028', 'X': '1999 / 2029',
      'Y': '2000 / 2030', '1': '2001', '2': '2002', '3': '2003', '4': '2004',
      '5': '2005', '6': '2006', '7': '2007', '8': '2008', '9': '2009',
    };
    return map[char] ?? 'Unknown ($char)';
  }

  static ScanResult parse(String rawText) {
    final vinRegex = RegExp(r'\b[A-HJ-NPR-Z0-9]{17}\b', caseSensitive: false);
    final match = vinRegex.firstMatch(rawText.toUpperCase());

    if (match != null) {
      final vin = match.group(0)!;
      final expectedCheckDigit = calculateCheckDigit(vin);
      final actualCheckDigit = vin[8];
      final isCheckDigitValid = expectedCheckDigit == actualCheckDigit;

      final wmi = vin.substring(0, 3);
      final manufacturer = _wmiMap[wmi] ?? 'Region/Manufacturer Code: $wmi';
      final modelYear = decodeModelYear(vin[9]);

      return ScanResult(
        mode: ScanMode.vin,
        rawValue: vin,
        isValid: isCheckDigitValid,
        confidence: isCheckDigitValid ? 0.99 : 0.85,
        fields: {
          'Document Type': 'ISO 3779 Vehicle Identification Number',
          'VIN Number': vin,
          'Check Digit (Pos 9)': '$actualCheckDigit (${isCheckDigitValid ? 'Valid ✓' : 'Invalid ✗'})',
          'Manufacturer / WMI': manufacturer,
          'Model Year (Pos 10)': modelYear,
          'Plant Code (Pos 11)': vin[10],
          'Sequential Number': vin.substring(11, 17),
        },
        metadata: {
          'vin': vin,
          'wmi': wmi,
          'isValidCheckDigit': isCheckDigitValid,
        },
      );
    }

    return ScanResult(
      mode: ScanMode.vin,
      rawValue: rawText,
      isValid: false,
      confidence: 0.3,
      fields: {
        'Document Type': 'VIN Number (Unparsed)',
        'Raw Input': rawText,
      },
    );
  }
}
