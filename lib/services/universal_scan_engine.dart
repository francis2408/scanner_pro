import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import '../core/parsers/aadhaar_parser.dart';
import '../core/parsers/driving_license_parser.dart';
import '../core/parsers/gs1_barcode_parser.dart';
import '../core/parsers/mrz_passport_parser.dart';
import '../core/parsers/pan_card_parser.dart';
import '../core/parsers/vin_parser.dart';

/// Orchestrates ML Kit vision AI models and routes camera/image inputs to specialized parsers.
class UniversalScanEngine {
  late final BarcodeScanner _barcodeScanner;
  late final TextRecognizer _textRecognizer;
  late final FaceDetector _faceDetector;

  bool _isInitialized = false;

  /// Initializes underlying Google ML Kit vision models.
  void initialize() {
    if (_isInitialized) return;
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );
    _isInitialized = true;
  }

  /// Closes and disposes active ML Kit resources.
  void dispose() {
    if (!_isInitialized) return;
    _barcodeScanner.close();
    _textRecognizer.close();
    _faceDetector.close();
    _isInitialized = false;
  }

  /// Processes an image from a local file path.
  Future<ScanResult> processImageFile(String imagePath, ScanMode mode) async {
    initialize();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      return await processInputImage(inputImage, mode, imagePath: imagePath);
    } catch (e) {
      return ScanResult.error(mode, 'Failed to process image: ${e.toString()}');
    }
  }

  /// Processes an ML Kit [InputImage] for the specified [ScanMode].
  Future<ScanResult> processInputImage(
    InputImage inputImage,
    ScanMode mode, {
    String? imagePath,
  }) async {
    initialize();

    switch (mode) {
      case ScanMode.qr:
      case ScanMode.barcode:
      case ScanMode.pdf417:
        return await _processBarcodes(inputImage, mode, imagePath: imagePath);

      case ScanMode.passport:
      case ScanMode.aadhaar:
      case ScanMode.pan:
      case ScanMode.drivingLicense:
      case ScanMode.vin:
      case ScanMode.ocr:
        return await _processTextAndDocuments(
          inputImage,
          mode,
          imagePath: imagePath,
        );

      case ScanMode.face:
        return await _processFaces(inputImage, mode, imagePath: imagePath);
    }
  }

  Future<ScanResult> _processBarcodes(
    InputImage inputImage,
    ScanMode mode, {
    String? imagePath,
  }) async {
    final barcodes = await _barcodeScanner.processImage(inputImage);

    if (barcodes.isEmpty) {
      if (imagePath != null) {
        final textResult = await _textRecognizer.processImage(inputImage);
        if (textResult.text.isNotEmpty) {
          return ScanResult(
            mode: mode,
            rawValue: textResult.text,
            isValid: true,
            confidence: 0.70,
            imagePath: imagePath,
            fields: {
              'Recognized Text': textResult.text,
              'Scan Type': mode.title,
            },
          );
        }
      }
      return ScanResult.error(
        mode,
        'No barcode or code pattern detected in frame.',
      );
    }

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue ?? barcode.displayValue ?? '';
    final formatStr = barcode.format.name;
    final typeStr = barcode.type.name;

    final Map<String, String> fields = _parseStructuredBarcodeValues(
      rawValue,
      typeStr,
      formatStr,
    );

    if (mode == ScanMode.pdf417 &&
        (rawValue.contains('@') || rawValue.contains('ANSI'))) {
      return DrivingLicenseParser.parse(rawValue);
    }

    return ScanResult(
      mode: mode,
      rawValue: rawValue,
      isValid: rawValue.isNotEmpty,
      confidence: 0.99,
      imagePath: imagePath,
      fields: fields,
      metadata: {'format': formatStr, 'type': typeStr},
    );
  }

  Map<String, String> _parseStructuredBarcodeValues(
    String rawValue,
    String typeStr,
    String formatStr,
  ) {
    Map<String, String> fields = {
      'Symbology Format': formatStr,
      'Value Type': typeStr.toUpperCase(),
      'Raw Payload': rawValue,
      'Payload Length': '${rawValue.length} characters',
    };

    final gs1Fields = Gs1BarcodeParser.parseGs1Payload(rawValue);
    if (gs1Fields.isNotEmpty) {
      fields.addAll(gs1Fields);
      fields['Value Type'] = 'GS1 BARCODE (AI ENCODED)';
    }

    if (rawValue.startsWith('WIFI:')) {
      fields['Value Type'] = 'WIFI NETWORK';
      final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(rawValue);
      final passMatch = RegExp(r'P:([^;]+)').firstMatch(rawValue);
      final typeMatch = RegExp(r'T:([^;]+)').firstMatch(rawValue);
      if (ssidMatch != null) fields['WiFi SSID'] = ssidMatch.group(1)!;
      if (passMatch != null) fields['Password'] = passMatch.group(1)!;
      if (typeMatch != null) {
        fields['Security Encryption'] = typeMatch.group(1)!;
      }
    } else if (rawValue.startsWith('http://') ||
        rawValue.startsWith('https://')) {
      fields['Value Type'] = 'WEB URL';
      fields['URL Link'] = rawValue;
    } else if (rawValue.startsWith('BEGIN:VCARD') ||
        rawValue.contains('N:') ||
        rawValue.contains('TEL:')) {
      fields['Value Type'] = 'VCARD CONTACT';
      final nameMatch = RegExp(
        r'FN:([^\n\r]+)|N:([^\n\r]+)',
      ).firstMatch(rawValue);
      final telMatch = RegExp(r'TEL[^:]*:([^\n\r]+)').firstMatch(rawValue);
      final emailMatch = RegExp(r'EMAIL[^:]*:([^\n\r]+)').firstMatch(rawValue);
      final orgMatch = RegExp(r'ORG:([^\n\r]+)').firstMatch(rawValue);
      if (nameMatch != null) {
        fields['Contact Name'] =
            (nameMatch.group(1) ?? nameMatch.group(2) ?? '')
                .replaceAll(';', ' ')
                .trim();
      }
      if (telMatch != null) fields['Phone Number'] = telMatch.group(1)!;
      if (emailMatch != null) fields['Email Address'] = emailMatch.group(1)!;
      if (orgMatch != null) fields['Organization'] = orgMatch.group(1)!;
    } else if (rawValue.startsWith('MATMSG:') ||
        rawValue.startsWith('mailto:')) {
      fields['Value Type'] = 'EMAIL MESSAGE';
      final emailMatch = RegExp(
        r'TO:([^;]+)|mailto:([^?]+)',
      ).firstMatch(rawValue);
      final subMatch = RegExp(
        r'SUB:([^;]+)|\?subject=([^&]+)',
      ).firstMatch(rawValue);
      if (emailMatch != null) {
        fields['Recipient Email'] =
            (emailMatch.group(1) ?? emailMatch.group(2) ?? '').trim();
      }
      if (subMatch != null) {
        fields['Subject'] = (subMatch.group(1) ?? subMatch.group(2) ?? '')
            .trim();
      }
    } else if (rawValue.startsWith('tel:')) {
      fields['Value Type'] = 'PHONE NUMBER';
      fields['Phone Number'] = rawValue.substring(4);
    } else if (rawValue.startsWith('geo:')) {
      fields['Value Type'] = 'GEO LOCATION';
      final coords = rawValue.substring(4).split(',');
      if (coords.isNotEmpty) fields['Latitude'] = coords[0];
      if (coords.length > 1) fields['Longitude'] = coords[1];
    }

    return fields;
  }

  Future<ScanResult> _processTextAndDocuments(
    InputImage inputImage,
    ScanMode mode, {
    String? imagePath,
  }) async {
    if (mode == ScanMode.aadhaar || mode == ScanMode.drivingLicense) {
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        final rawVal = barcodes.first.rawValue ?? '';
        if (rawVal.isNotEmpty) {
          if (mode == ScanMode.aadhaar) return AadhaarParser.parse(rawVal);
          if (mode == ScanMode.drivingLicense) {
            return DrivingLicenseParser.parse(rawVal);
          }
        }
      }
    }

    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    if (rawText.isEmpty) {
      return ScanResult.error(
        mode,
        'No legible text detected. Ensure good illumination.',
      );
    }

    ScanResult result;

    switch (mode) {
      case ScanMode.passport:
        result = MrzPassportParser.parse(rawText);
        break;
      case ScanMode.aadhaar:
        result = AadhaarParser.parse(rawText);
        break;
      case ScanMode.pan:
        result = PanCardParser.parse(rawText);
        break;
      case ScanMode.drivingLicense:
        result = DrivingLicenseParser.parse(rawText);
        break;
      case ScanMode.vin:
        result = VinParser.parse(rawText);
        break;
      case ScanMode.ocr:
      default:
        final lines = rawText
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        final words = rawText
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();
        result = ScanResult(
          mode: ScanMode.ocr,
          rawValue: rawText,
          isValid: true,
          confidence: 0.95,
          imagePath: imagePath,
          fields: {
            'Text Recognition Engine': 'Google ML Kit Latin OCR',
            'Total Blocks Detected': '${recognizedText.blocks.length}',
            'Total Lines': '${lines.length}',
            'Total Word Count': '${words.length}',
            'Total Character Count': '${rawText.length}',
            'Line 1 Preview': lines.isNotEmpty ? lines[0] : 'N/A',
            'Line 2 Preview': lines.length > 1 ? lines[1] : 'N/A',
          },
        );
        break;
    }

    return result;
  }

  Future<ScanResult> _processFaces(
    InputImage inputImage,
    ScanMode mode, {
    String? imagePath,
  }) async {
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return ScanResult.error(mode, 'No face detected in camera view.');
    }

    final face = faces.first;
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    final smile = face.smilingProbability;
    final yaw = face.headEulerAngleY;
    final pitch = face.headEulerAngleX;
    final roll = face.headEulerAngleZ;

    final isLivenessPass =
        (leftEye != null && leftEye > 0.4) &&
        (rightEye != null && rightEye > 0.4) &&
        (yaw != null && yaw.abs() < 25);

    return ScanResult(
      mode: ScanMode.face,
      rawValue:
          'Face Detected at [L:${face.boundingBox.left.toInt()}, T:${face.boundingBox.top.toInt()}, W:${face.boundingBox.width.toInt()}, H:${face.boundingBox.height.toInt()}]',
      isValid: isLivenessPass,
      confidence: isLivenessPass ? 0.98 : 0.70,
      imagePath: imagePath,
      fields: {
        'Total Faces Detected': '${faces.length}',
        'Liveness Verification': isLivenessPass
            ? 'Passed ✓'
            : 'Alert: Low Eye Openness / Head Tilt ✗',
        'Bounding Box Bounds':
            'L:${face.boundingBox.left.toInt()} T:${face.boundingBox.top.toInt()} W:${face.boundingBox.width.toInt()} H:${face.boundingBox.height.toInt()}',
        'Left Eye Open Probability': leftEye != null
            ? '${(leftEye * 100).toStringAsFixed(1)}%'
            : 'N/A',
        'Right Eye Open Probability': rightEye != null
            ? '${(rightEye * 100).toStringAsFixed(1)}%'
            : 'N/A',
        'Smile Probability': smile != null
            ? '${(smile * 100).toStringAsFixed(1)}%'
            : 'N/A',
        'Head Yaw (Side Rotation)': yaw != null
            ? '${yaw.toStringAsFixed(1)}°'
            : 'N/A',
        'Head Pitch (Up/Down Tilt)': pitch != null
            ? '${pitch.toStringAsFixed(1)}°'
            : 'N/A',
        'Head Roll (Side Tilt)': roll != null
            ? '${roll.toStringAsFixed(1)}°'
            : 'N/A',
        'Tracking ID': face.trackingId != null
            ? '#${face.trackingId}'
            : 'Active',
      },
      metadata: {
        'boundingBox': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'width': face.boundingBox.width,
          'height': face.boundingBox.height,
        },
        'smile': smile,
        'leftEye': leftEye,
        'rightEye': rightEye,
      },
    );
  }
}
