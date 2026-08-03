# 1.1.1

- Dependency Constraint Update: Expanded `google_mlkit_commons` dependency constraint to `>=0.9.0 <0.13.0` to support up-to-date stable versions (`0.11.0` & `0.12.0`).

# 1.1.0

- ML Kit Dependency Streamlining: Refactored vision scanning engine to rely exclusively on `google_mlkit_commons`, removing individual sub-package dependencies.
- Sub-Millisecond Vision Performance: Replaced dynamic regular expressions with static compiled constants and pre-cached camera byte buffers, delivering sub-millisecond parsing latency (down to 13 µs per operation) and up to ~76,900 ops/sec throughput.
- Enriched Document Metadata & Accuracy: Added ISO 3166-1 country name resolution, composite ICAO 7-3-1 checks, age calculations, Aadhaar Verhoeff validation, PAN taxpayer category breakdowns, expanded WMI manufacturer databases (50+ global vehicle makes), and Face Liveness verification.
- Performance Benchmark Test Suite: Added comprehensive unit & throughput benchmark tests (`test/performance_benchmark_test.dart`).

# 1.0.9

- Standalone Scanning Engine & Custom Screen Design: Added `ScannerController` and `ScannerCameraPreview` widgets to decouple camera lifecycle, ML vision scanning, and stream processing from pre-packaged UI layouts.
- Custom Builder Support: Added `UniversalScannerView.builder(...)` constructor allowing developers to build custom screen UI designs with full access to scanner functionality.
- Updated documentation and example applications demonstrating custom screen UI design usage.

# 1.0.8

- README Image Rendering Fix: Updated banner and UI preview graphics in `README.md` to use GitHub raw image URLs and standard Markdown syntax for pub.dev web rendering compatibility.

# 1.0.7

- Documentation & Graphics Upgrade: Redesigned `README.md` with complete feature guides, multi-document scanning matrices, platform setup instructions, and high-resolution visual banner/theme preview image graphics (`doc/assets/`).
- Primary SDK Export: Added `lib/scannerpro.dart` entry point for clean library imports (`import 'package:scannerpro/scannerpro.dart';`).

# 1.0.6

- Package Payload & Archive Optimization: Added `.pubignore` to strip IDE cache, gradle wrappers, build trees, and unused workspace files from the published pub package.
- Android Binary Shrinking: Enabled R8 bytecode minification (`isMinifyEnabled = true`), resource shrinking (`isShrinkResources = true`), and custom `proguard-rules.pro` for release builds.
- Removed redundant `google_mlkit_commons` dependency declaration.

# 1.0.5

- Binary size optimization: Removed unused transitive packages (`google_fonts` and `cupertino_icons`) to streamline package payload.
- Added Android Google Play Services unbundled ML Kit vision model metadata (`com.google.mlkit.vision.DEPENDENCIES`) to download models dynamically on demand, saving up to ~30 MB APK binary size while keeping 100% scanning functionality intact.

# 1.0.4

- Added complete UI design and color customization via `ScannerUiTheme` (`ScannerUiTheme.dark`, `ScannerUiTheme.cyan`, `ScannerUiTheme.emerald`, `ScannerUiTheme.amber`, and custom themes).
- Configurable viewfinder reticle colors, corner bracket dimensions, laser beam colors, overlay dimming mask, text styling, and visibility toggles on `UniversalScannerView`.

# 1.0.3

- Resolved static analysis Pana lint issues (`curly_braces_in_flow_control_structures`) for 160/160 Pana pub points.
- Added mode enable feature flags (`enableAadhaar`, `enablePan`, `enablePassport`, `enableQr`, etc.) and `enabledModes` access control to `UniversalScannerView`.

# 1.0.2

- Maintenance release and package updates.

# 1.0.1

- OSI-approved MIT License and standard SPDX license recognition.
- Comprehensive 100% Dartdoc API documentation for 160/160 Pana pub points.
- Package example app implementation in `example/`.
- Updated dependency ranges for latest Flutter and Dart SDKs.

# 1.0.0+1

- Initial release of Scanner Pro cross-platform Flutter application.
- Real-time OCR and Barcode detection powered by Google ML Kit.
- Dynamic REST API lookup pipeline (Open Food Facts, UPC Item DB, Open Library, OpenStreetMap Nominatim, India Post, NHTSA VIN).
- Multiformat document parsing engine:
  - Indian Aadhaar Card (Verhoeff D10 checksum + Secure XML/OCR).
  - Income Tax PAN Card (10-char classification + surname decoding + fuzzy OCR correction).
  - UPI Payment QR (GPay, PhonePe, Paytm, Amazon Pay account details).
  - Passports (ICAO Doc 9303 MRZ checksums + Country API metadata).
  - Driving Licenses (AAMVA PDF417 + US Zippopotam lookup).
  - Vehicle VIN (ISO 3779 17-char check digit + NHTSA API specs).
  - GS1 Barcodes & Retail 1D/2D Symbologies.
