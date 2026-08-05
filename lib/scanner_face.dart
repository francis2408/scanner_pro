/// Minimal import barrel for face-detection-only consumers.
///
/// Use `import 'package:scannerpro/scanner_face.dart'` when you only need
/// [ScanResult], [ScanMode], and [UniversalScanEngine] without pulling in the
/// full SDK surface (UI widgets, parsers, exporters, etc.).
///
/// For the full SDK, use `import 'package:scannerpro/scannerpro.dart'` instead.
library;

export 'core/models/scan_result.dart';
export 'core/models/scanner_mode.dart';
export 'services/universal_scan_engine.dart';
