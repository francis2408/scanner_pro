import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannerpro/core/models/scanner_mode.dart';
import 'package:scannerpro/core/models/scanner_theme.dart';
import 'package:scannerpro/main.dart';
import 'package:scannerpro/ui/widgets/universal_scanner_view.dart';

void main() {
  testWidgets('Universal Scanner App renders dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const UniversalScannerApp());

    expect(find.text('Universal Scanner'), findsOneWidget);
    expect(find.text('Android & iOS Cross-Platform SDK'), findsOneWidget);
  });

  test('UniversalScannerView resolves activeEnabledModes correctly', () {
    const defaultScanner = UniversalScannerView();
    expect(defaultScanner.activeEnabledModes.length, ScanMode.values.length);

    const aadhaarOnly = UniversalScannerView(
      enableAadhaar: true,
      enablePan: false,
      enableQr: false,
      enableBarcode: false,
      enablePdf417: false,
      enablePassport: false,
      enableDrivingLicense: false,
      enableVin: false,
      enableOcr: false,
      enableFace: false,
      enableDocument: false,
      enableInvoice: false,
      enableReceipt: false,
      enableBusinessCard: false,
      enableMultiCode: false,
      enableCheque: false,
      enableIdCard: false,
      enableLicensePlate: false,
    );
    expect(aadhaarOnly.activeEnabledModes, [ScanMode.aadhaar]);

    const explicitModes = UniversalScannerView(
      enabledModes: [ScanMode.aadhaar, ScanMode.pan],
    );
    expect(explicitModes.activeEnabledModes, [ScanMode.aadhaar, ScanMode.pan]);
  });

  test('UniversalScannerView resolves custom UI theme and colors', () {
    const customScanner = UniversalScannerView(
      theme: ScannerUiTheme.emerald,
      primaryAccentColor: Color(0xFFFF0055),
      backgroundColor: Color(0xFF111111),
      showModeBadge: false,
    );

    final resolved = customScanner.resolvedTheme;
    expect(resolved.accentColor, const Color(0xFFFF0055));
    expect(resolved.backgroundColor, const Color(0xFF111111));
    expect(resolved.showModeBadge, false);
    expect(resolved.reticleCornerColor, const Color(0xFF00E676));
  });
}
