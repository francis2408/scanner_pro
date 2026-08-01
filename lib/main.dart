import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/models/scan_result.dart';
import 'core/models/scanner_mode.dart';
import 'ui/widgets/result_bottom_sheet.dart';
import 'ui/widgets/universal_scanner_view.dart';

/// Application entry point.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const UniversalScannerApp());
}

/// Root widget for Universal Scanner Pro application.
class UniversalScannerApp extends StatelessWidget {
  /// Constructs [UniversalScannerApp].
  const UniversalScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Scanner SDK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D12),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD600),
          surface: Color(0xFF161B22),
        ),
        textTheme: ThemeData.dark().textTheme,
      ),
      home: const MainScannerDashboard(),
    );
  }
}

class MainScannerDashboard extends StatefulWidget {
  const MainScannerDashboard({super.key});

  @override
  State<MainScannerDashboard> createState() => _MainScannerDashboardState();
}

class _MainScannerDashboardState extends State<MainScannerDashboard> {
  final List<ScanResult> _scanHistory = [];

  void _onResultDetected(ScanResult result) {
    setState(() {
      _scanHistory.insert(0, result);
      if (_scanHistory.length > 50) {
        _scanHistory.removeLast();
      }
    });
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history_rounded, color: Color(0xFF00E5FF)),
                    const SizedBox(width: 10),
                    Text(
                      'Scan History (${_scanHistory.length})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (_scanHistory.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _scanHistory.clear();
                      });
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            if (_scanHistory.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No scan history yet.\nTry scanning barcodes, passports, or ID cards!',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _scanHistory.length,
                  separatorBuilder: (c, i) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (c, index) {
                    final item = _scanHistory[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.mode.icon,
                          color: const Color(0xFF00E5FF),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item.mode.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        item.rawValue.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        ResultBottomSheet.show(context, item);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showSdkCodeSnippetModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.integration_instructions_rounded,
                  color: Color(0xFFFFD600),
                ),
                SizedBox(width: 10),
                Text(
                  'Universal Scanner SDK Usage',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Easily integrate all 10 scan modes into any Flutter app with cross-platform Android & iOS support:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const SelectableText(
                '''
// 1. Single facade widget with feature-flag access control:
UniversalScannerView(
  initialMode: ScanMode.aadhaar,
  enableAadhaar: true, // Selective access control flags
  enablePan: true,
  enablePassport: true,
  onResultDetected: (ScanResult result) {
    print('Scan Mode: \${result.mode.title}');
    print('Parsed Fields: \${result.fields}');
    print('Is Valid: \${result.isValid}');
  },
)

// 2. Or call standalone parsers directly:
final passportResult = MrzPassportParser.parse(mrzRawText);
final aadhaarResult  = AadhaarParser.parse(qrOrText);
final panResult      = PanCardParser.parse(ocrText);
final vinResult      = VinParser.parse(vin17String);
''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF00E5FF),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF00E5FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Universal Scanner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Android & iOS Cross-Platform SDK',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.code_rounded, color: Color(0xFFFFD600)),
            tooltip: 'SDK Usage Code',
            onPressed: _showSdkCodeSnippetModal,
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: Colors.white70),
                tooltip: 'Scan History',
                onPressed: _showHistoryModal,
              ),
              if (_scanHistory.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_scanHistory.length}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: UniversalScannerView(onResultDetected: _onResultDetected),
    );
  }
}
