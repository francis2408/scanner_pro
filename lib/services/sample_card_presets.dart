import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import '../core/parsers/mrz_passport_parser.dart';
import '../core/parsers/aadhaar_parser.dart';
import '../core/parsers/pan_card_parser.dart';
import '../core/parsers/driving_license_parser.dart';
import '../core/parsers/vin_parser.dart';
import '../core/parsers/invoice_parser.dart';
import '../core/parsers/receipt_parser.dart';
import '../core/parsers/bank_cheque_parser.dart';
import '../core/parsers/business_card_parser.dart';

/// Container class for preset sample card scan items.
class SampleCardPresets {
  /// Returns sample items available for a specific [ScanMode].
  static List<SampleItem> getSamplesForMode(ScanMode mode) {
    switch (mode) {
      case ScanMode.qr:
        return [
          SampleItem(
            label: 'WiFi Network QR',
            payload: 'WIFI:S:Universal_Scanner_5G;T:WPA;P:super_secret_pass;;',
            mode: ScanMode.qr,
          ),
          SampleItem(
            label: 'vCard Contact QR',
            payload:
                'BEGIN:VCARD\nVERSION:3.0\nN:Scanner;Universal;;;\nFN:Universal Scanner SDK\nORG:DeepMind Tech\nTEL;TYPE=WORK,VOICE:+18005550199\nEMAIL:scanner@sdk.internal\nEND:VCARD',
            mode: ScanMode.qr,
          ),
          SampleItem(
            label: 'UPI Payment QR',
            payload:
                'upi://pay?pa=universalscanner@bank&pn=Universal%20Scanner%20SDK&am=250.00&cu=INR',
            mode: ScanMode.qr,
          ),
        ];

      case ScanMode.barcode:
        return [
          SampleItem(
            label: 'EAN-13 Retail Barcode',
            payload: '8901030748194',
            mode: ScanMode.barcode,
          ),
          SampleItem(
            label: 'Code-128 Shipment Tracking',
            payload: '1Z9999999999999999',
            mode: ScanMode.barcode,
          ),
        ];

      case ScanMode.pdf417:
        return [
          SampleItem(
            label: 'Airline Boarding Pass PDF417',
            payload:
                'M1DESMARAIS/LUC       EABC123 YULCDGAF 0833 015F001A0001 100',
            mode: ScanMode.pdf417,
          ),
        ];

      case ScanMode.passport:
        return [
          SampleItem(
            label: 'USA Passport MRZ (TD3)',
            payload:
                'P<USADICKSON<<BENJAMIN<FRANKLIN<<<<<<<<<<<<<\n1234567897USA8501019M3001018<<<<<<<<<<<<<<04',
            mode: ScanMode.passport,
          ),
          SampleItem(
            label: 'German ID Card MRZ (TD1)',
            payload:
                'IDD<<T220001293<<<<<<<<<<<<<<<\n6408125M2010315D<<<<<<<<<<<<^6\nMUSTREMANN<<ERIKA<<<<<<<<<<<<<',
            mode: ScanMode.passport,
          ),
        ];

      case ScanMode.aadhaar:
        return [
          SampleItem(
            label: 'Aadhaar Secure QR XML',
            payload:
                '<?xml version="1.0" encoding="UTF-8"?><PrintLetterBarcodeData uid="234567890124" name="Rajesh Kumar" gender="M" yob="1992" co="S/O Ramesh Kumar" house="42" street="MG Road" loc="Indiranagar" vtc="Bengaluru" dist="Bengaluru" state="Karnataka" pc="560038"/>',
            mode: ScanMode.aadhaar,
          ),
          SampleItem(
            label: 'Aadhaar Card OCR Front',
            payload:
                'GOVERNMENT OF INDIA\nRajesh Kumar\nDOB: 15/08/1992\nMale\n2345 6789 0124\nVID: 9182 7364 5512 3456',
            mode: ScanMode.aadhaar,
          ),
        ];

      case ScanMode.pan:
        return [
          SampleItem(
            label: 'Individual PAN Card',
            payload:
                'INCOME TAX DEPARTMENT\nGOVT OF INDIA\nABCDE1234F\nNAME: RAJESH KUMAR\nFATHER: RAMESH KUMAR\nDOB: 15/08/1992',
            mode: ScanMode.pan,
          ),
          SampleItem(
            label: 'Company PAN Card',
            payload:
                'INCOME TAX DEPARTMENT\nGOVT OF INDIA\nCPKCS9876K\nNAME: TECH INNOVATIONS PRIVATE LIMITED\nDATE OF INCORPORATION: 10/02/2018',
            mode: ScanMode.pan,
          ),
        ];

      case ScanMode.drivingLicense:
        return [
          SampleItem(
            label: 'AAMVA US DL PDF417',
            payload:
                '@\n\nANSI 636000080002DL00390207DLDAQD1234567\nDCSDOE\nDACJOHN\nDADEDWARD\nDBB19880415\nDBA22001231\nDBD20200415\nDBC1\nDAG123 MAIN STREET\nDAISPRINGFIELD\nDAJVA\nDAK221500000\n',
            mode: ScanMode.drivingLicense,
          ),
          SampleItem(
            label: 'Indian DL Card OCR',
            payload:
                'UNION OF INDIA DRIVING LICENSE\nMAHARASHTRA STATE\nDL NO: MH02 20210084729\nName: VIKRAM SHARMA\nDOB: 24/11/1990\nValid Until: 23/11/2040\nClass: LMV, MCWG',
            mode: ScanMode.drivingLicense,
          ),
        ];

      case ScanMode.vin:
        return [
          SampleItem(
            label: 'Honda USA VIN (ISO 3779)',
            payload: '1HGCR2F83HA123456',
            mode: ScanMode.vin,
          ),
          SampleItem(
            label: 'BMW Germany VIN',
            payload: 'WBA3A5C55CF123456',
            mode: ScanMode.vin,
          ),
        ];

      case ScanMode.ocr:
        return [
          SampleItem(
            label: 'Printed Document Text Block',
            payload:
                'SCANNER PRO ULTIMATE SDK\nHigh Performance On-Device Computer Vision\nReal-time ML Kit OCR Engine with Sub-Millisecond Latency\nSupports iOS, Android, macOS and Web',
            mode: ScanMode.ocr,
          ),
        ];

      case ScanMode.face:
        return [
          SampleItem(
            label: 'Sample Face Analysis Preset',
            payload: 'FACE_SIMULATION_METRICS',
            mode: ScanMode.face,
          ),
        ];

      case ScanMode.document:
        return [
          SampleItem(
            label: 'Document Page Scanner',
            payload: 'DOCUMENT_PAGE_QUAD_BOUNDS',
            mode: ScanMode.document,
          ),
        ];

      case ScanMode.invoice:
        return [
          SampleItem(
            label: 'Tax Invoice OCR',
            payload: r'''GLOBAL SUPPLIERS CORP
INVOICE NO: INV-2026-8841
DATE: 2026-08-01  DUE: 2026-08-30
GSTIN: 27AAAAA0000A1Z5
--------------------------------
Item 1: Server Hardware Rack   $1,250.00
Item 2: Fiber Optics Adapter     $450.00
--------------------------------
SUBTOTAL:                      $1,700.00
TAX (18%):                       $306.00
TOTAL AMOUNT:                  $2,006.00''',
            mode: ScanMode.invoice,
          ),
        ];

      case ScanMode.receipt:
        return [
          SampleItem(
            label: 'Store Receipt OCR',
            payload: r'''SUPERMARKET EXPRESS
Receipt #: 45981
Date: Aug 02, 2026
--------------------------------
Fresh Milk 1L            $3.50
Whole Wheat Bread        $2.80
Organic Coffee Beans    $14.99
--------------------------------
SUBTOTAL:               $21.29
TAX:                     $1.70
TOTAL:                  $22.99
Thank you for shopping!''',
            mode: ScanMode.receipt,
          ),
        ];

      case ScanMode.businessCard:
        return [
          SampleItem(
            label: 'Executive Business Card',
            payload: '''BENJAMIN FRANKLIN
Chief Executive Officer
ALEXANDRIA TECH SOLUTIONS INC.
Tel: +1 (800) 555-0199
Email: benjamin@alexandria.tech
Web: www.alexandria.tech
123 Innovation Way, Suite 400, Austin TX 78701''',
            mode: ScanMode.businessCard,
          ),
        ];

      case ScanMode.multiCode:
        return [
          SampleItem(
            label: 'Multi-Code Batch Scanner',
            payload: '8901030748194\n---\nhttps://flutter.dev\n---\nWIFI:S:OfficeGuest;P:guest123;;',
            mode: ScanMode.multiCode,
          ),
        ];

      case ScanMode.cheque:
        return [
          SampleItem(
            label: 'Bank Cheque MICR Codeline',
            payload: 'c000123c 021000021a 001234c 10\nPAY TO THE ORDER OF: John Doe\nAMOUNT: \$1,250.00\nDATE: 15/08/2026\nBANK: JPMorgan Chase Bank',
            mode: ScanMode.cheque,
          ),
        ];
    }
  }

  static ScanResult processSample(SampleItem sample) {
    switch (sample.mode) {
      case ScanMode.qr:
        return ScanResult(
          mode: ScanMode.qr,
          rawValue: sample.payload,
          isValid: true,
          confidence: 1.0,
          fields: {
            'Format': 'QR Code (2D)',
            'Content Type': sample.payload.startsWith('WIFI:')
                ? 'WiFi Credentials'
                : (sample.payload.startsWith('BEGIN:VCARD')
                      ? 'vCard Contact'
                      : (sample.payload.startsWith('upi:')
                            ? 'UPI Payment'
                            : 'URL / Text')),
            'Payload': sample.payload,
          },
        );

      case ScanMode.barcode:
        return ScanResult(
          mode: ScanMode.barcode,
          rawValue: sample.payload,
          isValid: true,
          confidence: 1.0,
          fields: {
            'Format': sample.payload.length == 13 ? 'EAN-13' : 'Code-128',
            'Value': sample.payload,
          },
        );

      case ScanMode.pdf417:
        return ScanResult(
          mode: ScanMode.pdf417,
          rawValue: sample.payload,
          isValid: true,
          confidence: 0.99,
          fields: {
            'Format': 'PDF417 (2D Stacked Barcode)',
            'Raw Payload': sample.payload,
          },
        );

      case ScanMode.passport:
        return MrzPassportParser.parse(sample.payload);

      case ScanMode.aadhaar:
        return AadhaarParser.parse(sample.payload);

      case ScanMode.pan:
        return PanCardParser.parse(sample.payload);

      case ScanMode.drivingLicense:
        return DrivingLicenseParser.parse(sample.payload);

      case ScanMode.vin:
        return VinParser.parse(sample.payload);

      case ScanMode.invoice:
        return InvoiceParser.parse(sample.payload);

      case ScanMode.receipt:
        return ReceiptParser.parse(sample.payload);

      case ScanMode.businessCard:
        return BusinessCardParser.parse(sample.payload);

      case ScanMode.ocr:
        return ScanResult(
          mode: ScanMode.ocr,
          rawValue: sample.payload,
          isValid: true,
          confidence: 0.95,
          fields: {
            'Text Type': 'Document OCR',
            'Extracted Lines':
                '${sample.payload.split('\n').length} Lines Recognized',
            'Full Text': sample.payload,
          },
        );

      case ScanMode.document:
        return ScanResult(
          mode: ScanMode.document,
          rawValue: 'Scanned Document Page',
          isValid: true,
          confidence: 0.99,
          fields: {
            'Document Edge Bounds': 'Detected Quad Corner Box',
            'Perspective Matrix': 'Corrected 4-Corner Rect',
            'Filter State': 'Shadow Removal Whitened Paper',
          },
        );

      case ScanMode.multiCode:
        return ScanResult(
          mode: ScanMode.multiCode,
          rawValue: sample.payload,
          isValid: true,
          confidence: 0.99,
          fields: {
            'Multi-Code Detection': '3 Codes Found',
            'Code #1': '8901030748194',
            'Code #2': 'https://flutter.dev',
            'Code #3': 'WIFI:S:OfficeGuest;P:guest123;;',
          },
          metadata: {
            'multiCodes': [
              '8901030748194',
              'https://flutter.dev',
              'WIFI:S:OfficeGuest;P:guest123;;'
            ]
          },
        );

      case ScanMode.face:
        return ScanResult(
          mode: ScanMode.face,
          rawValue:
              'Face Detected (Bounding Box: [L: 120, T: 180, R: 360, B: 480])',
          isValid: true,
          confidence: 0.98,
          fields: {
            'Face Detected': '1 Face in Frame',
            'Liveness Check': 'Passed (Blink & Smile Detected) ✓',
            'Left Eye Open': '98.5%',
            'Right Eye Open': '97.2%',
            'Smiling Probability': '89.4%',
            'Head Pose Yaw': '1.2° (Centered)',
            'Head Pose Pitch': '-0.5° (Straight)',
            'Head Pose Roll': '0.1° (Level)',
          },
          metadata: {
            'leftEyeOpen': 0.985,
            'rightEyeOpen': 0.972,
            'smile': 0.894,
            'headYaw': 1.2,
            'headPitch': -0.5,
          },
        );

      case ScanMode.cheque:
        final chequeInfo = BankChequeParser.parse(sample.payload);
        return ScanResult(
          mode: ScanMode.cheque,
          rawValue: sample.payload,
          isValid: chequeInfo.isValidMicr,
          confidence: 0.98,
          fields: chequeInfo.toFields(),
          bankChequeInfo: chequeInfo,
        );
    }
  }
}

/// Represents a single sample payload item used for mode demonstration.
class SampleItem {
  /// User-facing label for the sample.
  final String label;

  /// The raw payload text of the sample.
  final String payload;

  /// The associated [ScanMode].
  final ScanMode mode;

  /// Constructs a new [SampleItem].
  SampleItem({required this.label, required this.payload, required this.mode});
}
