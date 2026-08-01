# Universal Scanner Pro SDK (`scannerpro`)

![Scanner Pro Banner](https://raw.githubusercontent.com/francis2408/scanner_pro/main/doc/assets/scanner_pro_banner.png)

[![Pub Version](https://img.shields.io/pub/v/scannerpro.svg)](https://pub.dev/packages/scannerpro)
[![Pub Points](https://img.shields.io/pub/points/scannerpro)](https://pub.dev/packages/scannerpro/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform: Android | iOS](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen.svg)](https://flutter.dev)

---

## Overview

**Universal Scanner Pro** is an enterprise-grade Flutter SDK for real-time document parsing, vision AI detection, and automated REST API lookups across **10 scanning modes**.

Equipped with Google ML Kit Vision AI, mathematical checksum validators (Verhoeff D10, ICAO Doc 9303, ISO 3779), and direct external REST API enrichments, **Scanner Pro** delivers instant document verification, custom reticle designs, and feature-flag access control.

---

## Custom UI Design & Visual Themes

![Scanner UI Preview](https://raw.githubusercontent.com/francis2408/scanner_pro/main/doc/assets/scanner_ui_preview.png)

Customize the viewfinder visual aesthetic to match your brand design system:
- **Built-in Presets**: `ScannerUiTheme.dark`, `ScannerUiTheme.cyan`, `ScannerUiTheme.emerald`, `ScannerUiTheme.amber`.
- **Custom Color Overrides**: Reticle corners, border outlines, laser beam colors, viewfinder mask opacity, and background containers.
- **Dimensional Controls**: Custom reticle corner radii, stroke widths, bracket lengths, and element toggles.

---

## 🌟 Key Features

### 📄 1. Multi-Document & Vision AI Engines (10 Scan Modes)
| Mode | Target Document / Symbology | Parsing & Validation Pipeline |
| :--- | :--- | :--- |
| **Aadhaar Card** | Indian Aadhaar Secure QR & Front OCR | Verhoeff D10 checksum + XML/OCR text extractor + India Post Pincode API |
| **PAN Card** | Income Tax Permanent Account Number | 10-char structural regex + Surname decoding + Fuzzy OCR space/letter repair |
| **Passport MRZ** | Passports & ICAO Doc 9303 MRZ Lines | 2-line & 3-line MRZ parser + 7-3-1 weight check digits + Country metadata |
| **Driving License** | AAMVA PDF417 Barcode & State DL OCR | AAMVA 3-character field decoding + Expiration & issue date extractors |
| **Vehicle VIN** | 17-character ISO 3779 Vehicle Number | Transposition check digit + WMI manufacturer decode + Live NHTSA API |
| **1D Barcode** | EAN-13, EAN-8, UPC-A, Code39, Code128 | Retail barcode parser + Open Food Facts & UPC Item DB REST lookups |
| **QR Code** | URLs, WiFi, VCard, Geo, UPI QR | UPI payment extractor (VPA, GPay/PhonePe, SBI, MCC) + Web metadata API |
| **PDF417** | Stacked 2D Barcodes | High-density ID card & boarding pass parsing |
| **Text OCR** | Print & Handwriting Recognition | General on-device text block & line extraction |
| **Face AI** | Face Landmark & Pose Detection | Eye landmark mesh circles + Face oval reticle guide |

---

### 🛡️ 2. Selective Access Control (Feature Flags)
Selectively enable or restrict scanner modes based on feature flags or explicit mode lists:

```dart
// Enable only Aadhaar and PAN Card scanning
UniversalScannerView(
  enableAadhaar: true,
  enablePan: true,
  enablePassport: false,
  enableDrivingLicense: false,
  enableQr: false,
)
```

---

### ⚡ 3. Binary Size & Performance Optimization
- **Unbundled Google Play Services ML Models**: Downloads vision models on demand via Google Play Services (`com.google.mlkit.vision.DEPENDENCIES`), saving **~25–35 MB** in APK download size.
- **R8 Bytecode & Resource Shrinking**: Automated bytecode minification and resource stripping via ProGuard optimization rules.
- **Zero Unused Dependencies**: Streamlined transitive dependencies for minimal package footprint.

---

## 🚀 Getting Started

### Installation

Add `scannerpro` to your `pubspec.yaml`:

```yaml
dependencies:
  scannerpro: ^1.0.8
```

Run `flutter pub get`.

---

## 💻 Usage Examples

### 1. Simple Scanner Widget
```dart
import 'package:flutter/material.dart';
import 'package:scannerpro/scannerpro.dart';

class MyScannerScreen extends StatelessWidget {
  const MyScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: UniversalScannerView(
        initialMode: ScanMode.qr,
        onResultDetected: (ScanResult result) {
          debugPrint('Scanned Mode: ${result.mode.title}');
          debugPrint('Parsed Data: ${result.fields}');
          debugPrint('Validity: ${result.isValid}');
        },
      ),
    );
  }
}
```

---

### 2. Custom UI Design & Theme Presets
```dart
UniversalScannerView(
  // Use preset theme:
  theme: ScannerUiTheme.emerald,

  // Or override individual design parameters:
  primaryAccentColor: const Color(0xFFFF0055), // Custom Neon Pink
  backgroundColor: const Color(0xFF10141D),
  overlayMaskColor: Colors.black.withOpacity(0.75),
  laserBeamColor: const Color(0xFFFFD600),
  showModeBadge: true,
  showGuideBox: true,
  showLaserBeam: true,
)
```

---

### 3. Feature-Flagged Document Access Control
```dart
UniversalScannerView(
  initialMode: ScanMode.aadhaar,
  enableAadhaar: true,
  enablePan: true,
  enablePassport: true,
  enableDrivingLicense: false,
  enableQr: false,
  enableBarcode: false,
)
```

---

### 4. Direct Standalone Parser APIs
You can also use standalone mathematical parsers directly without opening the camera view:

```dart
import 'package:scannerpro/scannerpro.dart';

// Parse Indian Aadhaar Card QR/OCR text:
final aadhaarResult = AadhaarParser.parse(rawTextOrXml);
print('UID Checksum Valid: ${aadhaarResult.isValid}');

// Parse Income Tax PAN Card text:
final panResult = PanCardParser.parse('ABCPE1234F');
print('Taxpayer Category: ${panResult.fields['Taxpayer Category']}');

// Parse Passport MRZ string:
final passportResult = MrzPassportParser.parse(mrzLines);
print('Passport Number: ${passportResult.fields['Passport Number']}');
```

---

## 🔧 Platform Setup

### Android Setup (`android/app/src/main/AndroidManifest.xml`)

Add camera permissions and the unbundled ML Kit vision model downloader:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application ...>
        <!-- Unbundled ML Kit vision models (Saves ~30 MB APK size) -->
        <meta-data
            android:name="com.google.mlkit.vision.DEPENDENCIES"
            android:value="barcode,ocr,face" />
    </application>
</manifest>
```

### iOS Setup (`ios/Runner/Info.plist`)

Add the camera usage permission string:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan documents, QR codes, and barcodes.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires photo library access to select document images for scanning.</string>
```

---

## 📄 License

This project is licensed under the OSI-Approved **MIT License**.
