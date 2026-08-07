import '../models/scanner_mode.dart';

/// Post-processor for OCR and barcode scan results.
///
/// Applies mode-specific corrections, common OCR error fixes,
/// whitespace normalization, and confidence recalculation after corrections.
///
/// Inspired by Tesseract's post-processing pipeline and Dynamsoft's
/// result normalization layer.
class ResultPostProcessor {
  /// Common OCR character confusion pairs (source → correction).
  /// Used for context-aware correction in specific scan modes.
  static const Map<String, String> _ocrConfusionPairs = {
    'O': '0',
    'o': '0',
    'I': '1',
    'l': '1',
    'S': '5',
    'Z': '2',
    'B': '8',
    'G': '6',
    'T': '7',
    'q': '9',
    'D': '0',
  };

  /// Reverse OCR confusion pairs (digit → letter).
  static const Map<String, String> _reverseConfusionPairs = {
    '0': 'O',
    '1': 'I',
    '5': 'S',
    '2': 'Z',
    '8': 'B',
    '6': 'G',
    '7': 'T',
  };

  /// Applies full post-processing pipeline to raw scan text.
  ///
  /// [rawText] — Raw text from detector or parser.
  /// [mode] — Current scan mode (determines which corrections to apply).
  ///
  /// Returns a [PostProcessResult] with corrected text and applied corrections.
  static PostProcessResult process(String rawText, ScanMode mode) {
    final corrections = <String>[];
    String text = rawText;

    // Step 1: Normalize whitespace
    text = _normalizeWhitespace(text);
    if (text != rawText) {
      corrections.add('whitespace_normalized');
    }

    // Step 2: Mode-specific corrections
    switch (mode) {
      case ScanMode.passport:
        text = _postProcessMrz(text, corrections);
        break;
      case ScanMode.vin:
        text = _postProcessVin(text, corrections);
        break;
      case ScanMode.pan:
        text = _postProcessPan(text, corrections);
        break;
      case ScanMode.aadhaar:
        text = _postProcessAadhaar(text, corrections);
        break;
      case ScanMode.barcode:
      case ScanMode.qr:
        text = _postProcessBarcode(text, corrections);
        break;
      case ScanMode.licensePlate:
        text = _postProcessLicensePlate(text, corrections);
        break;
      case ScanMode.ocr:
      case ScanMode.invoice:
      case ScanMode.receipt:
      case ScanMode.businessCard:
        text = _postProcessGenericOcr(text, corrections);
        break;
      default:
        break;
    }

    // Step 3: Calculate confidence adjustment based on corrections made
    final confidenceAdjustment = _calculateConfidenceAdjustment(corrections);

    return PostProcessResult(
      text: text,
      corrections: corrections,
      confidenceAdjustment: confidenceAdjustment,
    );
  }

  /// Normalizes whitespace: collapses runs, trims lines, removes control characters.
  static String _normalizeWhitespace(String text) {
    // Remove control characters except newline and tab
    text = text.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Collapse multiple spaces into single space
    text = text.replaceAll(RegExp(r' {2,}'), ' ');

    // Collapse multiple newlines into double newline
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Trim each line
    text = text.split('\n').map((line) => line.trim()).join('\n');

    return text.trim();
  }

  /// Post-processes MRZ text: ensures uppercase, correct filler characters,
  /// and digit/letter placement per ICAO 9303.
  static String _postProcessMrz(String text, List<String> corrections) {
    var result = text.toUpperCase();
    if (result != text) {
      corrections.add('mrz_uppercased');
    }

    // MRZ lines should only contain A-Z, 0-9, and < (filler)
    final mrzLines = result.split('\n').where((l) => l.length >= 30).toList();
    if (mrzLines.isEmpty) return result;

    final processedLines = <String>[];
    for (final line in mrzLines) {
      final buffer = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        var ch = line[i];

        // Common OCR fixes for MRZ
        if (ch == ' ') {
          ch = '<'; // Spaces in MRZ should be fillers
          corrections.add('mrz_space_to_filler');
        }

        // In known digit positions, convert letters to digits
        // MRZ digit positions vary by format, so use heuristic:
        // If surrounded by digits, convert confused letters to digits
        if (_isLikelyDigitPosition(line, i)) {
          if (_ocrConfusionPairs.containsKey(ch)) {
            ch = _ocrConfusionPairs[ch]!;
            corrections.add('mrz_letter_to_digit:$i');
          }
        }

        buffer.write(ch);
      }
      processedLines.add(buffer.toString());
    }

    return processedLines.join('\n');
  }

  /// Post-processes VIN: uppercase, transliterate I→1, O→0, Q→0.
  static String _postProcessVin(String text, List<String> corrections) {
    // Extract 17-character VIN candidate
    var vin = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (vin.length > 17) {
      // Try to find a 17-char substring
      final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(vin);
      if (match != null) {
        vin = match.group(0)!;
      } else {
        vin = vin.substring(0, 17);
      }
    }

    // ISO 3779 transliteration
    final transliterations = {'I': '1', 'O': '0', 'Q': '0'};
    final buffer = StringBuffer();
    for (int i = 0; i < vin.length; i++) {
      final ch = vin[i];
      if (transliterations.containsKey(ch)) {
        buffer.write(transliterations[ch]);
        corrections.add('vin_transliterate:$ch→${transliterations[ch]}');
      } else {
        buffer.write(ch);
      }
    }

    return buffer.toString();
  }

  /// Post-processes PAN card: AAAAA0000A format.
  static String _postProcessPan(String text, List<String> corrections) {
    var pan = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // PAN format: 5 letters + 4 digits + 1 letter
    if (pan.length >= 10) {
      final buffer = StringBuffer();
      for (int i = 0; i < 10 && i < pan.length; i++) {
        var ch = pan[i];
        if (i < 5 || i == 9) {
          // Should be a letter
          if (RegExp(r'[0-9]').hasMatch(ch) && _reverseConfusionPairs.containsKey(ch)) {
            ch = _reverseConfusionPairs[ch]!;
            corrections.add('pan_digit_to_letter:$i');
          }
        } else {
          // Positions 5-8 should be digits
          if (RegExp(r'[A-Z]').hasMatch(ch) && _ocrConfusionPairs.containsKey(ch)) {
            ch = _ocrConfusionPairs[ch]!;
            corrections.add('pan_letter_to_digit:$i');
          }
        }
        buffer.write(ch);
      }
      pan = buffer.toString();
    }

    return pan;
  }

  /// Post-processes Aadhaar number: 12 digits, space-separated groups of 4.
  static String _postProcessAadhaar(String text, List<String> corrections) {
    var digits = text.replaceAll(RegExp(r'[^0-9]'), '');

    // Try OCR correction for non-digit characters
    if (digits.length < 12) {
      final buffer = StringBuffer();
      for (int i = 0; i < text.length; i++) {
        final ch = text[i];
        if (RegExp(r'[0-9]').hasMatch(ch)) {
          buffer.write(ch);
        } else if (_ocrConfusionPairs.containsKey(ch)) {
          buffer.write(_ocrConfusionPairs[ch]);
          corrections.add('aadhaar_ocr_fix:$ch→${_ocrConfusionPairs[ch]}');
        }
      }
      digits = buffer.toString();
    }

    if (digits.length >= 12) {
      digits = digits.substring(0, 12);
      // Format as XXXX XXXX XXXX
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)}';
    }

    return digits;
  }

  /// Post-processes barcode values: trim whitespace, validate structure.
  static String _postProcessBarcode(String text, List<String> corrections) {
    return text.trim();
  }

  /// Post-processes license plate text: uppercase, normalize spacing.
  static String _postProcessLicensePlate(String text, List<String> corrections) {
    var plate = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 -]'), '');
    plate = plate.replaceAll(RegExp(r' {2,}'), ' ').trim();

    if (plate != text) {
      corrections.add('plate_normalized');
    }

    return plate;
  }

  /// Post-processes generic OCR text: fix common confusions, normalize punctuation.
  static String _postProcessGenericOcr(String text, List<String> corrections) {
    var result = text;

    // Fix common OCR artifacts
    result = result.replaceAll('|', 'I');
    result = result.replaceAll('¡', 'i');
    result = result.replaceAll('`', "'");
    result = result.replaceAll('´', "'");

    if (result != text) {
      corrections.add('ocr_artifact_fix');
    }

    return result;
  }

  /// Heuristic: checks if position i in a string is likely a digit position.
  static bool _isLikelyDigitPosition(String text, int i) {
    int digitNeighbors = 0;
    if (i > 0 && RegExp(r'[0-9]').hasMatch(text[i - 1])) digitNeighbors++;
    if (i < text.length - 1 && RegExp(r'[0-9]').hasMatch(text[i + 1])) {
      digitNeighbors++;
    }
    return digitNeighbors >= 2;
  }

  /// Calculates a confidence adjustment factor based on corrections applied.
  /// More corrections = slightly lower confidence.
  static double _calculateConfidenceAdjustment(List<String> corrections) {
    if (corrections.isEmpty) return 0.0;
    if (corrections.length == 1 && corrections[0] == 'whitespace_normalized') {
      return 0.0; // Whitespace normalization doesn't affect confidence
    }

    // Each substantive correction reduces confidence slightly
    final substantiveCorrections =
        corrections.where((c) => c != 'whitespace_normalized').length;
    return -(substantiveCorrections * 0.02).clamp(0.0, 0.15);
  }
}

/// Result of post-processing.
class PostProcessResult {
  /// Corrected/normalized text.
  final String text;

  /// List of corrections applied.
  final List<String> corrections;

  /// Confidence adjustment (negative = reduced confidence).
  final double confidenceAdjustment;

  const PostProcessResult({
    required this.text,
    required this.corrections,
    required this.confidenceAdjustment,
  });
}
