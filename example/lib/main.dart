import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ScannerExampleApp());
}

/// Universal Scanner Pro Feature Showcase Application.
class ScannerExampleApp extends StatelessWidget {
  const ScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScannerPro Showcase Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D12),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD600),
          surface: Color(0xFF161B22),
        ),
      ),
      home: const MainShowcaseDashboard(),
    );
  }
}

class MainShowcaseDashboard extends StatefulWidget {
  const MainShowcaseDashboard({super.key});

  @override
  State<MainShowcaseDashboard> createState() => _MainShowcaseDashboardState();
}

class _MainShowcaseDashboardState extends State<MainShowcaseDashboard> {
  int _currentTabIndex = 0;
  late ScannerController _controller;
  ScanResult? _latestResult;
  final List<ScanResult> _sessionHistory = [];

  @override
  void initState() {
    super.initState();
    _controller = ScannerController(
      initialMode: ScanMode.qr,
      options: const ScannerOptions(
        scanStrategy: ScanStrategy.continuous,
        enableAdaptiveFps: true,
        enableIsolateProcessing: true,
        duplicateTimeout: Duration(milliseconds: 2000),
      ),
      onResultDetected: (result) {
        setState(() {
          _latestResult = result;
          _sessionHistory.insert(0, result);
          if (_sessionHistory.length > 100) {
            _sessionHistory.removeLast();
          }
        });
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
    final tabs = [
      _buildLiveScannerTab(),
      _buildDocumentStudioTab(),
      _buildIdParsersTab(),
      _buildBatchWarehouseTab(),
      _buildBenchmarkTelemetryTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF00E5FF)),
            ),
            const SizedBox(width: 10),
            const Text(
              'ScannerPro v2.2.0',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle Flashlight',
            icon: Icon(
              _controller.isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _controller.isFlashOn ? const Color(0xFFFFD600) : Colors.white70,
            ),
            onPressed: () => _controller.toggleFlash(),
          ),
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            tooltip: 'Gallery Image Scan',
            icon: const Icon(Icons.photo_library_rounded),
            onPressed: () => _controller.pickAndScanImage(),
          ),
        ],
      ),
      body: tabs[_currentTabIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_rounded),
            label: 'Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_rounded),
            label: 'Document',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_rounded),
            label: 'ID Cards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Batch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed_rounded),
            label: 'Telemetry',
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Live Scanner & Reticle ---
  Widget _buildLiveScannerTab() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera Preview
            ScannerCameraPreview(controller: _controller),

            // Mode Selector Bar (Top)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ScanMode.values.map((mode) {
                    final isSelected = _controller.selectedMode == mode;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          children: [
                            Icon(
                              mode.icon,
                              size: 16,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(mode.title),
                          ],
                        ),
                        selectedColor: const Color(0xFF00E5FF),
                        backgroundColor: const Color(0xFF161B22).withValues(alpha: 0.85),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => _controller.setMode(mode),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Target Overlay Painter
            CustomPaint(
              painter: ScannerOverlayPainter(
                scanMode: _controller.selectedMode,
                animationValue: 0.5,
                accentColor: const Color(0xFF00E5FF),
              ),
            ),

            // Bottom Floating Controls & Result Card
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_latestResult != null) _buildResultCard(_latestResult!),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.zoom_in_rounded, size: 20, color: Color(0xFF00E5FF)),
                            const SizedBox(width: 8),
                            Text(
                              'Zoom: ${_controller.currentZoomLevel.toStringAsFixed(1)}x',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Slider(
                            value: _controller.currentZoomLevel,
                            min: _controller.minZoomLevel,
                            max: _controller.maxZoomLevel,
                            activeColor: const Color(0xFF00E5FF),
                            onChanged: (val) => _controller.setZoomLevel(val),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _controller.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: const Color(0xFFFFD600),
                          ),
                          onPressed: () {
                            if (_controller.isPaused) {
                              _controller.resumeScanning();
                            } else {
                              _controller.pauseScanning();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultCard(ScanResult result) {
    final validation = ScannerPro.validateResult(result);
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: validation.isValid ? Colors.greenAccent : Colors.redAccent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          validation.isValid ? Icons.check_circle_rounded : Icons.error_rounded,
          color: validation.isValid ? Colors.greenAccent : Colors.redAccent,
          size: 32,
        ),
        title: Text(
          result.mode.title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        subtitle: Text(
          result.rawValue,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: validation.isValid
                ? Colors.greenAccent.withValues(alpha: 0.15)
                : Colors.redAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            validation.isValid ? 'VALID ✓' : 'INVALID ✗',
            style: TextStyle(
              color: validation.isValid ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: Document Studio & PDF Export ---
  Widget _buildDocumentStudioTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Scanner Studio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Auto edge detection, quad perspective crop, blur score analysis, and multi-page PDF export.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 64, color: Color(0xFF00E5FF)),
                    const SizedBox(height: 16),
                    const Text(
                      'Ready for Page Capture',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Captured Pages: ${_sessionHistory.where((r) => r.mode == ScanMode.document).length}',
                      style: const TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Export Document Session to PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final docs = _sessionHistory.where((r) => r.mode == ScanMode.document).toList();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              docs.isNotEmpty
                                  ? 'PDF generated with ${docs.length} scanned pages ✓'
                                  : 'Scan document pages first in camera tab!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: ID Parsers Demo ---
  Widget _buildIdParsersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Identity Document Parsers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Instant rule-based parsing with Verhoeff & checksum validation.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildParserCard(
          title: 'Indian Aadhaar Card (UIDAI)',
          icon: Icons.credit_card_rounded,
          samplePayload: '2345 6789 0124 DOB: 15/08/1990 Male Pincode: 560001',
          onTest: () {
            final res = ScannerPro.scanAadhaar('2345 6789 0124 DOB: 15/08/1990 Male');
            _showParserDialog('Aadhaar Result', res);
          },
        ),
        _buildParserCard(
          title: 'Income Tax PAN Card',
          icon: Icons.subtitles_rounded,
          samplePayload: 'ABCPE1234F Name: JOHN DOE DOB: 01/01/1985',
          onTest: () {
            final res = ScannerPro.scanPanCard('ABCPE1234F Name: JOHN DOE DOB: 01/01/1985');
            _showParserDialog('PAN Card Result', res);
          },
        ),
        _buildParserCard(
          title: 'ICAO Passport (MRZ)',
          icon: Icons.badge_rounded,
          samplePayload: 'P<INDXAVIER<<FRANCIS<<<<<<<<<<<<<<<<<<<<<<\nZ1234567<8IND9008151M3001017<<<<<<<<<<<<<<04',
          onTest: () {
            final res = ScannerPro.scanPassport('P<INDXAVIER<<FRANCIS<<<<<<<<<<<<<<<<<<<<<<\nZ1234567<8IND9008151M3001017<<<<<<<<<<<<<<04');
            _showParserDialog('Passport Result', res);
          },
        ),
        _buildParserCard(
          title: 'ISO 3779 VIN Number',
          icon: Icons.minor_crash_rounded,
          samplePayload: '1HGCR2F83HA000000',
          onTest: () {
            final res = ScannerPro.scanVin('1HGCR2F83HA000000');
            _showParserDialog('VIN Result', res);
          },
        ),
        _buildParserCard(
          title: 'Business Card Contact',
          icon: Icons.contact_page_rounded,
          samplePayload: 'Francis Xavier\nCEO\nTech Corp\nEmail: info@tech.com\nPhone: +1234567890',
          onTest: () {
            final res = ScannerPro.scanBusinessCard('Francis Xavier\nCEO\nTech Corp\nEmail: info@tech.com\nPhone: +1234567890');
            _showParserDialog('Business Card Result', res);
          },
        ),
      ],
    );
  }

  Widget _buildParserCard({
    required String title,
    required IconData icon,
    required String samplePayload,
    required VoidCallback onTest,
  }) {
    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00E5FF)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(samplePayload, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
            foregroundColor: const Color(0xFF00E5FF),
          ),
          onPressed: onTest,
          child: const Text('Test Parser'),
        ),
      ),
    );
  }

  void _showParserDialog(String title, ScanResult result) {
    final validation = ScannerPro.validateResult(result);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Validation: ${validation.reason}', style: TextStyle(color: validation.isValid ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...result.fields.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // --- TAB 4: Batch Warehouse ---
  Widget _buildBatchWarehouseTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch Inventory Scanner', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('High-speed continuous scan with deduplication', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Count: ${_sessionHistory.length}', style: const TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _sessionHistory.isEmpty
                ? const Center(child: Text('No items scanned in current session', style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    itemCount: _sessionHistory.length,
                    itemBuilder: (ctx, idx) {
                      final item = _sessionHistory[idx];
                      return ListTile(
                        leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00E5FF)),
                        title: Text(item.rawValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('${item.mode.title} • ${item.timestamp.toIso8601String().substring(11, 19)}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- TAB 5: Benchmark & Telemetry ---
  Widget _buildBenchmarkTelemetryTab() {
    final telemetry = ScannerBenchmark.runLiveDiagnostic();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Performance Telemetry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        const Text('Real-time frame processing stats & hardware benchmarks.', style: TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard('Live FPS', '${_controller.fpsState.targetFps} FPS', Icons.speed_rounded, Colors.greenAccent),
            const SizedBox(width: 12),
            _buildStatCard('Latency', '${telemetry['Average Latency µs']} µs', Icons.timer_rounded, const Color(0xFF00E5FF)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('Memory', telemetry['Memory Footprint'], Icons.memory_rounded, const Color(0xFFFFD600)),
            const SizedBox(width: 12),
            _buildStatCard('CPU Load', telemetry['Estimated CPU Usage'], Icons.developer_board_rounded, Colors.purpleAccent),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Device Benchmark Standards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Device', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('FPS', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Memory', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('CPU', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: ScannerBenchmark.getSampleDeviceMetrics()
                .map((m) => DataRow(cells: [
                      DataCell(Text(m['Device'] ?? '')),
                      DataCell(Text('${m['FPS']}')),
                      DataCell(Text('${m['Memory MB']} MB')),
                      DataCell(Text('${m['CPU %']}%')),
                    ]))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
