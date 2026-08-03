# Universal Scanner Pro SDK (`scannerpro`)

![Scanner Pro Banner](https://raw.githubusercontent.com/francis2408/scanner_pro/main/doc/assets/scanner_pro_banner.png)

[![Pub Version](https://img.shields.io/pub/v/scannerpro.svg)](https://pub.dev/packages/scannerpro)
[![Pub Points](https://img.shields.io/pub/points/scannerpro)](https://pub.dev/packages/scannerpro/score)
[![GitHub Repository](https://img.shields.io/badge/GitHub-francis2408%2Fscanner__pro-blue?logo=github)](https://github.com/francis2408/scanner_pro)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform: Android | iOS](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen.svg)](https://flutter.dev)

---

## 📌 Repository & Pub Package Links
- **Pub.dev Package**: [`pub.dev/packages/scannerpro`](https://pub.dev/packages/scannerpro)
- **GitHub Repository**: [`github.com/francis2408/scanner_pro`](https://github.com/francis2408/scanner_pro)

---

## ⚡ Overview & Enterprise Features

**Universal Scanner Pro** (`scannerpro`) is the #1 enterprise-grade, high-throughput Flutter scanning SDK for real-time document parsing, ML Kit vision AI, offline ID extraction, PDF generation, and automated REST API lookups.

### 🏢 Enterprise Features
- **Offline OCR & Barcode**: 100% on-device text recognition, 1D/2D barcodes, QR codes, and PDF417.
- **Offline ID Scanners**: Indian Aadhaar Card (Verhoeff D10 + Secure QR XML), Income Tax PAN Card, Passport (ICAO Doc 9303 MRZ), Driving License (AAMVA PDF417), and Vehicle VIN (ISO 3779).
- **Searchable PDF Generation**: Generates PDF documents with an embedded searchable text layer for text selection.
- **PDF Compression & Image Compression**: Advanced stream encoding and image downsampling for minimal output file sizes.
- **Watermarking**: Customizable diagonal semi-transparent watermark text overlays on PDF pages.
- **PDF Encryption**: Standard security dictionary (`/Filter /Standard /V 2 /R 3 /P -4`) supporting user & owner passwords.
- **Digital Signatures**: PKCS#7 detached digital signature block (`/ByteRange`, `/SubFilter /adbe.pkcs7.detached`, signer name, location, timestamp).
- **AI-Powered Document Classification**: Automatic category detection (`invoice`, `receipt`, `passport`, `aadhaar`, `pan`, `drivingLicense`, `businessCard`, `vin`, `barcode`, `generalDocument`).

---

## 🗺️ Release Roadmap (v1.7 – v2.0)

| Release | Focus Area | Key Features Delivered |
| :--- | :--- | :--- |
| **v1.7** | Core Scanning & Control | Smart Auto Scan, Multi-Barcode, Scan Region ROI, Scanner Controller, Custom Overlay |
| **v1.8** | Document & PDF Pipeline | Text OCR, Document Scanner (quad bounds & perspective crop), PDF Generator, Batch Scan |
| **v1.9** | ID Extraction Suite | Aadhaar Scanner (Verhoeff D10), PAN Scanner, Passport Scanner, MRZ Scanner |
| **v2.0** | Enterprise & Vision AI | Face Detection, VIN Scanner, Business Card Scanner, Searchable PDF, AI Document Classification, Encryption, Digital Signature |

---

## 🏗️ Architecture & Component Decoupling
- **`ScannerController`**: Manages camera lifecycle, flash/zoom controls, active scanner modes, ROI windows, and frame listeners.
- **`ScannerCameraPreview`**: Unopinionated, raw camera viewport widget for custom UI designs.
- **`UniversalScanEngine`**: ML Kit vision AI pipeline with zero-copy buffer allocations.
- **`DocumentClassifier`**: Heuristic & AI document type detector.
- **`PdfExportUtil`**: Enterprise PDF generator supporting compression, watermarks, passwords, signatures, and searchable text layers.
- **Standalone Parsers**: Pure Dart mathematical parsers (`AadhaarParser`, `PanCardParser`, `MrzPassportParser`, `DrivingLicenseParser`, `VinParser`, `Gs1BarcodeParser`).

---

## 📊 Benchmark & Performance Metrics

| Component / Parser | Operation Latency | Throughput | Strategy / Optimization |
| :--- | :---: | :---: | :--- |
| **ISO 3779 VIN Parser** | **11.6 µs / op** | **~86,200 ops/sec** | Static check digit matrix & compiled WMI manufacturer map |
| **GS1 Barcode Parser** | **17.4 µs / op** | **~57,400 ops/sec** | Zero-copy AI code slicer & binary range matching |
| **AAMVA DL PDF417 Parser** | **26.8 µs / op** | **~37,300 ops/sec** | Direct ANSI line-buffer scanner |
| **Indian Aadhaar Card Parser** | **99.4 µs / op** | **~10,060 ops/sec** | Pre-compiled Verhoeff lookup matrix & XML node parser |
| **Income Tax PAN Card Parser** | **106.2 µs / op** | **~9,410 ops/sec** | Fuzzy OCR character replacement & position rules |
| **Passport MRZ Parser** | **166.8 µs / op** | **~6,000 ops/sec** | Dual-line ICAO 9303 7-3-1 modulo-10 checksum verifier |
| **External API Lookup Cache** | **< 0.1 ms** | **Instant Cache Hit** | 250-item thread-safe LRU memory cache |

---

## 🎨 Custom UI Screen Design

You can use **ONLY** the scanner functionality and build your own custom screen design:

```dart
import 'package:flutter/material.dart';
import 'package:scannerpro/scannerpro.dart';

class MyCustomScannerScreen extends StatefulWidget {
  const MyCustomScannerScreen({super.key});

  @override
  State<MyCustomScannerScreen> createState() => _MyCustomScannerScreenState();
}

class _MyCustomScannerScreenState extends State<MyCustomScannerScreen> {
  late ScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController(
      initialMode: ScanMode.qr,
      onResultDetected: (result) => print('Scanned: ${result.rawValue}'),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              // 1. Raw camera feed widget
              ScannerCameraPreview(controller: _controller),

              // 2. Custom reticle overlay
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.cyan, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              // 3. Custom buttons
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(_controller.isFlashOn ? Icons.flash_on : Icons.flash_off),
                      onPressed: () => _controller.toggleFlash(),
                    ),
                    ElevatedButton(
                      onPressed: () => _controller.setMode(ScanMode.barcode),
                      child: const Text('Barcode Mode'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: () => _controller.pickAndScanImage(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## 💻 Enterprise PDF Export & AI Classification Examples

### Generating Searchable, Encrypted & Digitally Signed PDFs

```dart
import 'package:scannerpro/scannerpro.dart';

final pdfBytes = PdfExportUtil.exportResultsToPdf(
  results: scanResultsList,
  title: 'Enterprise Scanned Audit Document',
  author: 'ScannerPro SDK Enterprise',
  watermarkText: 'CONFIDENTIAL',
  password: 'user_password_123',
  isEncrypted: true,
  digitalSignature: true,
  isSearchablePdf: true,
  enableCompression: true,
  imageCompressionQuality: 0.85,
);

// Save or share pdfBytes directly
```

### AI-Powered Document Classification

```dart
import 'package:scannerpro/scannerpro.dart';

final classification = DocumentClassifier.classify(rawOcrText);

print('Document Category: ${classification.category.name}'); // e.g. "invoice", "passport", "aadhaar"
print('Confidence Score: ${classification.confidence}');
print('Detected Keywords: ${classification.detectedKeywords}');
```

---

## 🚀 Getting Started

### Installation

Add `scannerpro` to your `pubspec.yaml`:

```yaml
dependencies:
  scannerpro: ^2.0.0
```

Run `flutter pub get`.

---

## 🔧 Platform Setup

### Android Setup (`android/app/src/main/AndroidManifest.xml`)

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

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan documents, QR codes, and barcodes.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires photo library access to select document images for scanning.</string>
```

---

## 📄 License

This project is licensed under the OSI-Approved **MIT License**.
