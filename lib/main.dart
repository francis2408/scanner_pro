import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/models/scan_result.dart';
import 'core/models/scanner_mode.dart';
import 'services/scanner_controller.dart';
import 'ui/widgets/result_bottom_sheet.dart';
import 'ui/widgets/scanner_camera_preview.dart';
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
  bool _useCustomScreenDesign = false;

  void _onResultDetected(ScanResult result) {
    final rawSnippet = result.rawValue.length > 60
        ? '${result.rawValue.substring(0, 57)}...'
        : result.rawValue.replaceAll(RegExp(r'[\r\n]+'), ' ');
    final logMsg =
        '📱 [MainApp] Scan result detected | Mode: ${result.mode.name} | Category: ${result.documentCategory} | Fetch Time: ${result.scanDuration?.inMilliseconds ?? 0} ms | Payload: "$rawSnippet"';
    log(logMsg);
    debugPrint(logMsg);
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
                  'Custom Screen Design & SDK Usage',
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
              'Use ONLY the scanner functionality and create your own screen design:',
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
// 1. Create standalone ScannerController & CameraPreview for custom UI:
final controller = ScannerController(
  initialMode: ScanMode.qr,
  onResultDetected: (result) => print(result.rawValue),
);
await controller.initialize();

// Render raw camera feed anywhere in your custom screen layout:
ScannerCameraPreview(controller: controller);

// 2. Or use UniversalScannerView.builder for custom screen designs:
UniversalScannerView.builder(
  builder: (context, controller, cameraPreview) {
    return Scaffold(
      body: Stack(
        children: [
          cameraPreview, // Camera feed
          MyCustomOverlay(), // Your own reticle & overlays
          MyCustomControlsBar(controller: controller), // Your own buttons
        ],
      ),
    );
  },
);
''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
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
              children: [
                Text(
                  _useCustomScreenDesign
                      ? 'Custom Screen UI'
                      : 'Universal Scanner',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _useCustomScreenDesign
                      ? 'Custom Screen Design Demo'
                      : 'Android & iOS Cross-Platform SDK',
                  style: const TextStyle(
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
            icon: Icon(
              _useCustomScreenDesign
                  ? Icons.dashboard_customize_rounded
                  : Icons.brush_rounded,
              color: _useCustomScreenDesign
                  ? const Color(0xFF00E5FF)
                  : Colors.white70,
            ),
            tooltip: _useCustomScreenDesign
                ? 'Switch to Standard UI'
                : 'Switch to Custom Design',
            onPressed: () {
              setState(() {
                _useCustomScreenDesign = !_useCustomScreenDesign;
              });
            },
          ),
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
      body: _useCustomScreenDesign
          ? CustomScreenDesignView(onResultDetected: _onResultDetected)
          : UniversalScannerView(onResultDetected: _onResultDetected),
    );
  }
}

/// Demonstration of how a package user can create their OWN screen design
/// using ONLY the scanning functionality from `ScannerController` & `ScannerCameraPreview`.
class CustomScreenDesignView extends StatefulWidget {
  final Function(ScanResult result)? onResultDetected;

  const CustomScreenDesignView({super.key, this.onResultDetected});

  @override
  State<CustomScreenDesignView> createState() => _CustomScreenDesignViewState();
}

class _CustomScreenDesignViewState extends State<CustomScreenDesignView> {
  late ScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController(
      initialMode: ScanMode.qr,
      onResultDetected: (result) {
        widget.onResultDetected?.call(result);
      },
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
        final activeMode = _controller.selectedMode;
        final lastResult = _controller.lastResult;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Raw camera feed (Functionality only!)
              ScannerCameraPreview(controller: _controller),

              // 2. Custom User-Designed Overlay & Target Framing
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00E5FF),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          activeMode.icon,
                          size: 48,
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Text(
                          'ALIGN ${activeMode.title.toUpperCase()}',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Custom Floating Mode Chips
              Positioned(
                top: 20,
                left: 16,
                right: 16,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ScanMode.values.take(6).map((mode) {
                      final isSelected = mode == activeMode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          avatar: Icon(
                            mode.icon,
                            size: 14,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                          label: Text(
                            mode.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF),
                          backgroundColor: Colors.black54,
                          onSelected: (_) => _controller.setMode(mode),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. Custom Floating Controls (Flash, Gallery, Switch Camera)
              Positioned(
                bottom: 30,
                left: 24,
                right: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lastResult != null && lastResult.isValid)
                      GestureDetector(
                        onTap: () =>
                            ResultBottomSheet.show(context, lastResult),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF161B22,
                            ).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF00E5FF,
                              ).withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00E676,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF00E676),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          lastResult.fields['Card Type'] ??
                                              lastResult.mode.title,
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Text(
                                          'Tap for details →',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDisplayFields(lastResult),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller.isFlashOn
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              color: _controller.isFlashOn
                                  ? const Color(0xFFFFD600)
                                  : Colors.white,
                            ),
                            onPressed: () => _controller.toggleFlash(),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(
                              Icons.photo_library_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Pick Image',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _controller.pickAndScanImage(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.cameraswitch_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => _controller.switchCamera(),
                          ),
                        ],
                      ),
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

  String _formatDisplayFields(ScanResult result) {
    final fields = result.fields;
    final name =
        fields['Full Name'] ??
        fields['Contact Name'] ??
        fields['Holder Category'];
    final number =
        fields['Aadhaar Number'] ??
        fields['PAN Number'] ??
        fields['Passport Number'] ??
        fields['Phone Number'] ??
        fields['Pincode'];
    final dob = fields['Date of Birth'] ?? fields['Gender'];

    final parts = [
      if (name != null && name.isNotEmpty) name,
      if (number != null && number.isNotEmpty) number,
      if (dob != null && dob.isNotEmpty) dob,
    ];

    if (parts.isNotEmpty) {
      return parts.join('  •  ');
    }
    return result.rawValue.replaceAll('\n', ' ');
  }
}
