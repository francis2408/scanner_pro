import 'package:flutter/material.dart';
import 'package:scannerpro/scannerpro.dart';

void main() {
  runApp(const ScannerExampleApp());
}

/// Example application demonstrating both standard SDK UI and Custom Screen Design capabilities.
class ScannerExampleApp extends StatelessWidget {
  /// Constructs the example app instance.
  const ScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Pro Custom Design Example',
      theme: ThemeData.dark(),
      home: const CustomDesignScannerPage(),
    );
  }
}

/// Page showcasing how developers can build their OWN screen design using ONLY functionality.
class CustomDesignScannerPage extends StatefulWidget {
  const CustomDesignScannerPage({super.key});

  @override
  State<CustomDesignScannerPage> createState() =>
      _CustomDesignScannerPageState();
}

class _CustomDesignScannerPageState extends State<CustomDesignScannerPage> {
  late ScannerController _controller;
  ScanResult? _latestResult;

  @override
  void initState() {
    super.initState();
    // Initialize standalone scanner controller
    _controller = ScannerController(
      initialMode: ScanMode.qr,
      onResultDetected: (result) {
        setState(() {
          _latestResult = result;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Custom UI Screen Design'),
        actions: [
          IconButton(
            icon: Icon(
              _controller.isFlashOn ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () => _controller.toggleFlash(),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () => _controller.pickAndScanImage(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Raw Camera Preview Functionality
              ScannerCameraPreview(controller: _controller),

              // 2. Custom Frame/Reticle Design
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'CUSTOM TARGET FRAME',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Custom Bottom Control Bar & Result Card
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_latestResult != null)
                      Card(
                        color: Colors.black87,
                        child: ListTile(
                          title: Text(_latestResult!.mode.title),
                          subtitle: Text(_latestResult!.rawValue),
                          leading: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _controller.setMode(ScanMode.qr),
                          child: const Text('QR Mode'),
                        ),
                        ElevatedButton(
                          onPressed: () => _controller.setMode(ScanMode.barcode),
                          child: const Text('Barcode Mode'),
                        ),
                        ElevatedButton(
                          onPressed: () => _controller.setMode(ScanMode.passport),
                          child: const Text('Passport Mode'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
