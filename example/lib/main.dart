import 'package:flutter/material.dart';
import 'package:scannerpro/ui/widgets/universal_scanner_view.dart';

void main() {
  runApp(const ScannerExampleApp());
}

/// Example application demonstrating the Universal Scanner Pro UI widget.
class ScannerExampleApp extends StatelessWidget {
  /// Constructs the example app instance.
  const ScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Pro Example',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: UniversalScannerView(
          enableAadhaar: true,
          enablePan: true,
          enablePassport: true,
          enableDrivingLicense: true,
          enableQr: true,
        ),
      ),
    );
  }
}
