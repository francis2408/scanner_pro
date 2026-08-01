import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/scan_result.dart';
import '../../core/models/scanner_mode.dart';
import '../../core/models/scanner_theme.dart';
import '../../services/universal_scan_engine.dart';
import 'result_bottom_sheet.dart';
import 'scanner_overlay_painter.dart';

/// Main camera viewfinder widget supporting mode switching, gallery picks, and reticle overlays.
class UniversalScannerView extends StatefulWidget {
  /// Initial mode when the scanner opens.
  final ScanMode initialMode;

  /// Optional explicit list of enabled scanning modes.
  final List<ScanMode>? enabledModes;

  /// Whether QR Code scanning mode is enabled.
  final bool enableQr;

  /// Whether 1D Barcode scanning mode is enabled.
  final bool enableBarcode;

  /// Whether PDF417 barcode scanning mode is enabled.
  final bool enablePdf417;

  /// Whether Passport MRZ scanning mode is enabled.
  final bool enablePassport;

  /// Whether Indian Aadhaar Card scanning mode is enabled.
  final bool enableAadhaar;

  /// Whether Income Tax PAN Card scanning mode is enabled.
  final bool enablePan;

  /// Whether Driving License scanning mode is enabled.
  final bool enableDrivingLicense;

  /// Whether Vehicle VIN scanning mode is enabled.
  final bool enableVin;

  /// Whether Text OCR scanning mode is enabled.
  final bool enableOcr;

  /// Whether Face Detection mode is enabled.
  final bool enableFace;

  /// Optional theme configuration for customizing UI design and colors.
  final ScannerUiTheme? theme;

  /// Primary accent color for viewfinder reticle, selected mode, and highlight lines.
  final Color? primaryAccentColor;

  /// Scanner viewport container background color.
  final Color? backgroundColor;

  /// Mode selection bottom bar background color.
  final Color? modeSelectorBackgroundColor;

  /// Background dimming color outside camera viewfinder cutout.
  final Color? overlayMaskColor;

  /// Color of animated scanning laser beam.
  final Color? laserBeamColor;

  /// Whether to display top active mode badge chip.
  final bool? showModeBadge;

  /// Whether to display top floating guidance text box.
  final bool? showGuideBox;

  /// Whether to display animated scanning laser beam.
  final bool? showLaserBeam;

  /// Optional callback invoked when a valid [ScanResult] is detected.
  final Function(ScanResult result)? onResultDetected;

  /// Constructs a new [UniversalScannerView].
  const UniversalScannerView({
    super.key,
    this.initialMode = ScanMode.qr,
    this.enabledModes,
    this.enableQr = true,
    this.enableBarcode = true,
    this.enablePdf417 = true,
    this.enablePassport = true,
    this.enableAadhaar = true,
    this.enablePan = true,
    this.enableDrivingLicense = true,
    this.enableVin = true,
    this.enableOcr = true,
    this.enableFace = true,
    this.theme,
    this.primaryAccentColor,
    this.backgroundColor,
    this.modeSelectorBackgroundColor,
    this.overlayMaskColor,
    this.laserBeamColor,
    this.showModeBadge,
    this.showGuideBox,
    this.showLaserBeam,
    this.onResultDetected,
  });

  /// Resolves the effective [ScannerUiTheme] merging [theme] and individual color overrides.
  ScannerUiTheme get resolvedTheme {
    final base = theme ?? ScannerUiTheme.dark;
    return ScannerUiTheme(
      overlayMaskColor: overlayMaskColor ?? base.overlayMaskColor,
      accentColor: primaryAccentColor ?? base.accentColor,
      reticleCornerColor: base.reticleCornerColor,
      reticleBorderColor: base.reticleBorderColor,
      laserBeamColor: laserBeamColor ?? base.laserBeamColor,
      backgroundColor: backgroundColor ?? base.backgroundColor,
      modeSelectorBackgroundColor:
          modeSelectorBackgroundColor ?? base.modeSelectorBackgroundColor,
      modeTabSelectedColor: base.modeTabSelectedColor,
      modeTabUnselectedColor: base.modeTabUnselectedColor,
      modeTabSelectedTextColor: base.modeTabSelectedTextColor,
      modeTabUnselectedTextColor: base.modeTabUnselectedTextColor,
      guideBoxBackgroundColor: base.guideBoxBackgroundColor,
      guideTextColor: base.guideTextColor,
      badgeBackgroundColor: base.badgeBackgroundColor,
      badgeTextColor: base.badgeTextColor,
      showModeBadge: showModeBadge ?? base.showModeBadge,
      showGuideBox: showGuideBox ?? base.showGuideBox,
      showLaserBeam: showLaserBeam ?? base.showLaserBeam,
      reticleCornerLength: base.reticleCornerLength,
      reticleCornerWidth: base.reticleCornerWidth,
      reticleBorderWidth: base.reticleBorderWidth,
      reticleCornerRadius: base.reticleCornerRadius,
    );
  }

  /// Resolves the list of active scanning modes enabled for this widget.
  List<ScanMode> get activeEnabledModes {
    if (enabledModes != null && enabledModes!.isNotEmpty) {
      return List.unmodifiable(enabledModes!);
    }
    final modes = <ScanMode>[];
    if (enableQr) modes.add(ScanMode.qr);
    if (enableBarcode) modes.add(ScanMode.barcode);
    if (enablePdf417) modes.add(ScanMode.pdf417);
    if (enablePassport) modes.add(ScanMode.passport);
    if (enableAadhaar) modes.add(ScanMode.aadhaar);
    if (enablePan) modes.add(ScanMode.pan);
    if (enableDrivingLicense) modes.add(ScanMode.drivingLicense);
    if (enableVin) modes.add(ScanMode.vin);
    if (enableOcr) modes.add(ScanMode.ocr);
    if (enableFace) modes.add(ScanMode.face);

    return modes.isEmpty ? ScanMode.values : List.unmodifiable(modes);
  }

  @override
  State<UniversalScannerView> createState() => _UniversalScannerViewState();
}

class _UniversalScannerViewState extends State<UniversalScannerView>
    with SingleTickerProviderStateMixin {
  late ScanMode _selectedMode;
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;

  final StreamController<ScanResult> _scanEventController =
      StreamController<ScanResult>.broadcast();
  late StreamSubscription<ScanResult> _scanEventSubscription;
  bool _isAnalyzingEvent = false;
  bool _isProcessingLiveFrame = false;
  String? _lastScannedPayload;
  DateTime? _lastScannedTime;
  Uint8List? _cachedNv21Buffer;
  DateTime? _lastFrameProcessedTime;

  late final AnimationController _laserAnimController;
  final UniversalScanEngine _scanEngine = UniversalScanEngine();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final available = widget.activeEnabledModes;
    if (available.contains(widget.initialMode)) {
      _selectedMode = widget.initialMode;
    } else {
      _selectedMode = available.first;
    }
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanEventSubscription = _scanEventController.stream.listen((result) {
      _onScanDataEventReceived(result);
    });

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        final camera = _availableCameras[_selectedCameraIndex];
        _cameraController = CameraController(
          camera,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
              ? ImageFormatGroup.yuv420
              : ImageFormatGroup.bgra8888,
        );

        await _cameraController!.initialize();
        _startLiveImageStream();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera init error (simulator or permissions): $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _startLiveImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isStreamingImages) {
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (!mounted || _isProcessingLiveFrame || _isAnalyzingEvent) return;

        final now = DateTime.now();
        if (_lastFrameProcessedTime != null &&
            now.difference(_lastFrameProcessedTime!).inMilliseconds < 150) {
          return;
        }

        _isProcessingLiveFrame = true;
        _lastFrameProcessedTime = now;

        try {
          final inputImage = _inputImageFromCameraImage(image);
          if (inputImage != null) {
            final result = await _scanEngine.processInputImage(
              inputImage,
              _selectedMode,
            );
            if (result.isValid && result.confidence >= 0.70) {
              _emitScanDataEvent(result);
            }
          }
        } catch (e) {
          // Silently skip unparseable transient frame
        } finally {
          _isProcessingLiveFrame = false;
        }
      });
    } catch (e) {
      debugPrint('Error starting live image stream: $e');
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || _availableCameras.isEmpty) return null;
    final camera = _availableCameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = defaultTargetPlatform == TargetPlatform.android
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    if (image.planes.isEmpty) return null;

    final Uint8List bytes = _convertCameraImageToBytes(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Uint8List _convertCameraImageToBytes(CameraImage image) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        image.planes.length == 3) {
      final yBuffer = image.planes[0].bytes;
      final uBuffer = image.planes[1].bytes;
      final vBuffer = image.planes[2].bytes;

      final int ySize = yBuffer.length;
      final int uSize = uBuffer.length;
      final int vSize = vBuffer.length;
      final int totalSize = ySize + (ySize ~/ 2);

      if (_cachedNv21Buffer == null || _cachedNv21Buffer!.length < totalSize) {
        _cachedNv21Buffer = Uint8List(totalSize);
      }

      final nv21 = _cachedNv21Buffer!;
      nv21.setRange(0, ySize, yBuffer);

      int nv21Index = ySize;
      for (int i = 0; i < uSize && nv21Index < totalSize; i++) {
        if (i < vSize) {
          nv21[nv21Index++] = vBuffer[i];
        }
        if (nv21Index < totalSize) {
          nv21[nv21Index++] = uBuffer[i];
        }
      }
      return nv21;
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  void dispose() {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController?.stopImageStream();
    }
    _scanEventSubscription.cancel();
    _scanEventController.close();
    _laserAnimController.dispose();
    _cameraController?.dispose();
    _scanEngine.dispose();
    super.dispose();
  }

  void _onSelectMode(ScanMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  Future<void> _toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length > 1) {
      _selectedCameraIndex =
          (_selectedCameraIndex + 1) % _availableCameras.length;
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
        } catch (_) {}
      }
      await _cameraController?.dispose();
      _cameraController = null;
      setState(() {
        _isCameraInitialized = false;
      });
      await _initCamera();
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isAnalyzingEvent) return;
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (file != null) {
        final result = await _scanEngine.processImageFile(
          file.path,
          _selectedMode,
        );
        _emitScanDataEvent(result);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery pick error: ${e.toString()}')),
      );
    }
  }

  void _emitScanDataEvent(ScanResult result) {
    if (!_scanEventController.isClosed && !_isAnalyzingEvent) {
      _scanEventController.add(result);
    }
  }

  Future<void> _onScanDataEventReceived(ScanResult result) async {
    if (_isAnalyzingEvent) return;
    _isAnalyzingEvent = true;

    final now = DateTime.now();
    if (_lastScannedPayload == result.rawValue &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(seconds: 4)) {
      _isAnalyzingEvent = false;
      return;
    }

    _lastScannedPayload = result.rawValue;
    _lastScannedTime = now;

    widget.onResultDetected?.call(result);

    await ResultBottomSheet.show(context, result);

    _isAnalyzingEvent = false;
  }

  @override
  Widget build(BuildContext context) {
    final uiTheme = widget.resolvedTheme;
    return Container(
      color: uiTheme.backgroundColor,
      child: Column(
        children: [
          _buildModeSelectorBar(),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isCameraInitialized &&
                    _cameraController != null &&
                    _cameraController!.value.isInitialized)
                  CameraPreview(_cameraController!)
                else
                  _buildSimulatorViewfinder(),

                AnimatedBuilder(
                  animation: _laserAnimController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: ScannerOverlayPainter(
                        scanMode: _selectedMode,
                        animationValue: _laserAnimController.value,
                        accentColor: _getCategoryColor(_selectedMode.category),
                        theme: uiTheme,
                      ),
                    );
                  },
                ),

                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isCameraInitialized)
                        _buildIconButton(
                          icon: _isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          onPressed: _toggleFlash,
                          active: _isFlashOn,
                        )
                      else
                        const SizedBox(width: 44),
                      if (uiTheme.showModeBadge)
                        _buildModeBadge()
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          _buildIconButton(
                            icon: Icons.photo_library_rounded,
                            onPressed: _pickImageFromGallery,
                          ),
                          if (_availableCameras.length > 1) ...[
                            const SizedBox(width: 8),
                            _buildIconButton(
                              icon: Icons.cameraswitch_rounded,
                              onPressed: _switchCamera,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (uiTheme.showGuideBox)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: uiTheme.guideBoxBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _getCategoryColor(_selectedMode.category),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedMode.guideText,
                              style: TextStyle(
                                color: uiTheme.guideTextColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorBar() {
    final availableModes = widget.activeEnabledModes;
    if (availableModes.length <= 1) {
      return const SizedBox.shrink();
    }
    final uiTheme = widget.resolvedTheme;
    return Container(
      height: 50,
      color: uiTheme.modeSelectorBackgroundColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final isSelected = mode == _selectedMode;
          final accentColor = _getCategoryColor(mode.category);
          final tabBgColor = isSelected
              ? (uiTheme.modeTabSelectedColor ?? accentColor)
              : uiTheme.modeTabUnselectedColor;
          final tabTextColor = isSelected
              ? uiTheme.modeTabSelectedTextColor
              : uiTheme.modeTabUnselectedTextColor;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => _onSelectMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tabBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.12),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 15,
                      color: isSelected ? tabTextColor : accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.title,
                      style: TextStyle(
                        color: tabTextColor,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimulatorViewfinder() {
    final uiTheme = widget.resolvedTheme;
    return Container(
      color: uiTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedMode.icon,
              size: 64,
              color: _getCategoryColor(
                _selectedMode.category,
              ).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '${_selectedMode.title} Scanner Viewfinder',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Point camera at target document or select image from gallery top right.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBadge() {
    final uiTheme = widget.resolvedTheme;
    final badgeColor =
        uiTheme.badgeTextColor ?? _getCategoryColor(_selectedMode.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: uiTheme.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        _selectedMode.title.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    final accent = _getCategoryColor(_selectedMode.category);
    return Container(
      decoration: BoxDecoration(
        color: active ? accent : Colors.black.withValues(alpha: 0.65),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.black : Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Color _getCategoryColor(String category) {
    if (widget.resolvedTheme.accentColor != null) {
      return widget.resolvedTheme.accentColor!;
    }
    switch (category) {
      case 'Barcodes':
        return const Color(0xFF00E5FF);
      case 'ID Documents':
        return const Color(0xFFFFD600);
      case 'Automotive':
        return const Color(0xFFFF4081);
      case 'Vision AI':
      default:
        return const Color(0xFF7C4DFF);
    }
  }
}
