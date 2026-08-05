import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/barcode_format.dart';
import '../core/models/camera_facing.dart';
import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import '../core/models/scanner_options.dart';
import '../ui/widgets/universal_scanner_view.dart';
import 'scanner_controller.dart';

/// Barcode capture payload matching `mobile_scanner` event structure.
class BarcodeCapture {
  /// List of detected barcodes in the frame pass.
  final List<BarcodeResult> barcodes;

  /// Raw scan result object.
  final ScanResult rawResult;

  /// Image dimensions if available.
  final Size? imageSize;

  const BarcodeCapture({
    required this.barcodes,
    required this.rawResult,
    this.imageSize,
  });
}

/// Standalone controller wrapper matching `mobile_scanner` API conventions.
class MobileScannerController extends ChangeNotifier {
  final ScannerController _controller;

  /// Constructs a [MobileScannerController].
  MobileScannerController({
    CameraFacing facing = CameraFacing.back,
    TorchState torchState = TorchState.off,
    List<BarcodeFormatFilter>? formats,
    double detectionTimeoutMs = 1000,
    bool autoStart = true,
  }) : _controller = ScannerController(
          initialMode: ScanMode.barcode,
          options: ScannerOptions(
            duplicateTimeout: Duration(milliseconds: detectionTimeoutMs.toInt()),
            allowedFormats: formats?.map((f) => f.nameString).toList(),
          ),
        ) {
    _controller.addListener(_onInternalControllerChanged);
    if (autoStart) {
      start();
    }
  }

  /// Underlying core scanner controller.
  ScannerController get scannerController => _controller;

  /// Active hardware camera facing direction.
  CameraFacing get facing => _controller.facing;

  /// Active flashlight torch state.
  TorchState get torchState => _controller.torchState;

  /// Stream emitting detected barcodes (`mobile_scanner` compatibility).
  Stream<BarcodeCapture> get barcodes => _controller.onResult.map((result) {
        final list = result.detectedBarcodes ??
            [
              BarcodeResult(
                format: result.format ?? 'BARCODE',
                rawValue: result.rawValue,
                displayValue: result.rawValue,
              )
            ];
        return BarcodeCapture(
          barcodes: list,
          rawResult: result,
          imageSize: result.imageSize,
        );
      });

  /// Starts live camera scanning.
  Future<void> start() async {
    await _controller.start();
  }

  /// Stops live camera scanning.
  Future<void> stop() async {
    await _controller.stop();
  }

  /// Toggles flashlight torch state.
  Future<void> toggleTorch() async {
    await _controller.toggleFlash();
  }

  /// Switches hardware camera facing direction.
  Future<void> switchCamera() async {
    await _controller.switchCamera();
  }

  /// Sets camera digital zoom scale factor.
  Future<void> setZoomScale(double zoom) async {
    await _controller.setZoomScale(zoom);
  }

  /// Scans local image file at [imagePath] (`mobile_scanner.analyzeImage` compatibility).
  Future<BarcodeCapture?> analyzeImage(String imagePath) async {
    final result = await _controller.analyzeImage(imagePath);
    if (!result.isValid) return null;
    final list = result.detectedBarcodes ??
        [
          BarcodeResult(
            format: result.format ?? 'BARCODE',
            rawValue: result.rawValue,
            displayValue: result.rawValue,
          )
        ];
    return BarcodeCapture(
      barcodes: list,
      rawResult: result,
      imageSize: result.imageSize,
    );
  }

  void _onInternalControllerChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.removeListener(_onInternalControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}

/// Viewfinder widget providing 100% API compatibility with `mobile_scanner`.
class MobileScanner extends StatelessWidget {
  /// Controller driving camera preview and barcode engine.
  final MobileScannerController controller;

  /// Callback invoked when barcodes are detected (`mobile_scanner` API compatibility).
  final void Function(BarcodeCapture capture)? onDetect;

  /// Optional custom overlay builder.
  final Widget Function(BuildContext context, MobileScannerController controller)? overlayBuilder;

  /// Constructs a [MobileScanner] widget.
  const MobileScanner({
    super.key,
    required this.controller,
    this.onDetect,
    this.overlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return UniversalScannerView(
      controller: controller.scannerController,
      onResultDetected: (res) {
        final list = res.detectedBarcodes ??
            [
              BarcodeResult(
                format: res.format ?? 'BARCODE',
                rawValue: res.rawValue,
                displayValue: res.rawValue,
              )
            ];
        onDetect?.call(
          BarcodeCapture(
            barcodes: list,
            rawResult: res,
            imageSize: res.imageSize,
          ),
        );
      },
      overlayBuilder: overlayBuilder != null
          ? (ctx, _) => overlayBuilder!(ctx, controller)
          : null,
    );
  }
}
