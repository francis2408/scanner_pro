import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import '../core/models/scanner_options.dart';
import 'isolate_frame_processor.dart';
import 'universal_scan_engine.dart';

/// Standalone controller managing hardware camera lifecycle, frame throttling,
/// background isolate processing, ROI sub-region cropping, duplicate caching,
/// tap-to-focus, auto-zoom, and low-light ambient brightness detection.
class ScannerController extends ChangeNotifier with WidgetsBindingObserver {
  /// Initial mode when scanner initializes.
  ScanMode _selectedMode;

  /// Resolution preset for camera controller.
  final cam.ResolutionPreset resolutionPreset;

  /// Configuration options controlling scan strategy, ROI, throttling, and timeouts.
  final ScannerOptions options;

  /// Optional callback invoked when a valid scan result is detected.
  final Function(ScanResult result)? onResultDetected;

  /// Optional callback invoked when ambient light changes (low light alert).
  final Function(bool isLowLight)? onLowLightDetected;

  /// Internal scan engine executing ML Kit vision models.
  final UniversalScanEngine _scanEngine;

  /// Image picker for gallery selection.
  final ImagePicker _imagePicker;

  cam.CameraController? _cameraController;
  List<cam.CameraDescription> _availableCameras = [];
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isFlashOn = false;
  int _selectedCameraIndex = 0;
  bool _isPaused = false;

  final StreamController<ScanResult> _scanEventController =
      StreamController<ScanResult>.broadcast();

  final StreamController<bool> _lowLightController =
      StreamController<bool>.broadcast();

  bool _isAnalyzingEvent = false;
  bool _isProcessingLiveFrame = false;
  String? _lastScannedPayload;
  DateTime? _lastScannedTime;
  Uint8List? _cachedNv21Buffer;
  DateTime? _lastFrameProcessedTime;
  ScanResult? _lastResult;
  String? _errorMessage;

  // Zoom and Focus properties
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 8.0;
  Offset? _lastTapFocusPoint;

  // Low Light analysis
  double _currentLuminosity = 0.5;
  bool _isLowLight = false;

  // Batch Scanning Queue
  final List<ScanResult> _batchResults = [];

  /// Constructs a [ScannerController].
  ScannerController({
    ScanMode initialMode = ScanMode.qr,
    this.resolutionPreset = cam.ResolutionPreset.high,
    this.options = const ScannerOptions(),
    this.onResultDetected,
    this.onLowLightDetected,
    UniversalScanEngine? scanEngine,
    ImagePicker? imagePicker,
  })  : _selectedMode = initialMode,
        _scanEngine = scanEngine ?? UniversalScanEngine(),
        _imagePicker = imagePicker ?? ImagePicker() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Whether camera controller and ML engine are initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Whether camera initialization is currently in progress.
  bool get isInitializing => _isInitializing;

  /// Whether flash/torch is currently turned on.
  bool get isFlashOn => _isFlashOn;

  /// Currently selected camera index in [availableCameras].
  int get selectedCameraIndex => _selectedCameraIndex;

  /// List of available hardware cameras on device.
  List<cam.CameraDescription> get availableCameras =>
      List.unmodifiable(_availableCameras);

  /// Active camera controller instance, if initialized.
  cam.CameraController? get cameraController => _cameraController;

  /// Currently active scanning mode.
  ScanMode get selectedMode => _selectedMode;

  /// Alias for active scanning mode.
  ScanMode get currentMode => _selectedMode;

  /// Whether live stream processing is currently paused.
  bool get isPaused => _isPaused;

  /// Stream emitting valid detected [ScanResult] objects.
  Stream<ScanResult> get onResult => _scanEventController.stream;

  /// Stream emitting low light status alerts.
  Stream<bool> get onLowLightStateChanged => _lowLightController.stream;

  /// Most recently detected [ScanResult].
  ScanResult? get lastResult => _lastResult;

  /// Last error message encountered during camera or scan operations.
  String? get errorMessage => _errorMessage;

  /// Current digital zoom level setting (1.0 to maxZoomLevel).
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;

  /// Most recent tap-to-focus point coordinates.
  Offset? get lastTapFocusPoint => _lastTapFocusPoint;

  /// Ambient frame relative brightness score (0.0 to 1.0).
  double get currentLuminosity => _currentLuminosity;

  /// Whether camera scene is currently under low ambient lighting.
  bool get isLowLight => _isLowLight;

  /// List of accumulated scan results collected in [ScanStrategy.batch] mode.
  List<ScanResult> get batchResults => List.unmodifiable(_batchResults);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      pauseScanning();
    } else if (state == AppLifecycleState.resumed) {
      resumeScanning();
    }
  }

  /// Pre-warms vision engine and hardware resources prior to UI layout assembly.
  Future<void> warmup() async {
    _scanEngine.initialize();
    await initialize();
  }

  /// Initializes hardware cameras and starts live stream processing.
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _scanEngine.initialize();
      _availableCameras = await availableCamerasFunc();
      if (_availableCameras.isNotEmpty) {
        final camera = _availableCameras[_selectedCameraIndex];
        _cameraController = cam.CameraController(
          camera,
          resolutionPreset,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
              ? cam.ImageFormatGroup.yuv420
              : cam.ImageFormatGroup.bgra8888,
        );

        await _cameraController!.initialize();

        try {
          _minZoomLevel = await _cameraController!.getMinZoomLevel();
          _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
        } catch (_) {}

        _startLiveImageStream();
        _isInitialized = true;
      } else {
        _errorMessage = 'No camera devices available on this hardware.';
      }
    } catch (e) {
      _errorMessage = 'Camera initialization failed: ${e.toString()}';
      debugPrint(_errorMessage);
      _isInitialized = false;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Exposed for testing dependency injection.
  @visibleForTesting
  Future<List<cam.CameraDescription>> availableCamerasFunc() async {
    try {
      return await cam.availableCameras();
    } catch (_) {
      return [];
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
      _cameraController!.startImageStream((cam.CameraImage image) async {
        if (_isPaused || _isProcessingLiveFrame || _isAnalyzingEvent) return;

        final now = DateTime.now();

        // Frame Throttling (e.g. max 10 FPS detection rate for low CPU/battery usage)
        if (_lastFrameProcessedTime != null &&
            now.difference(_lastFrameProcessedTime!).inMilliseconds <
                options.frameThrottleMs) {
          return;
        }

        _isProcessingLiveFrame = true;
        _lastFrameProcessedTime = now;

        try {
          // Process frame in background isolate if enabled
          if (options.enableIsolateProcessing) {
            final taskData = IsolateFrameTaskData(
              bytes: _convertCameraImageToBytes(image),
              width: image.width,
              height: image.height,
              bytesPerRow: image.planes.isNotEmpty
                  ? image.planes[0].bytesPerRow
                  : image.width,
              scanWindow: options.scanWindow,
              computeLuminosity: options.enableAutoBrightnessCheck,
            );

            final isolateResult =
                await IsolateFrameProcessor.processFrame(taskData);
            _updateLuminosityState(
              isolateResult.averageLuminosity,
              isolateResult.isLowLight,
            );

            final inputImage = _inputImageFromBytes(
              isolateResult.processedBytes,
              isolateResult.croppedWidth,
              isolateResult.croppedHeight,
              image.planes.isNotEmpty
                  ? image.planes[0].bytesPerRow
                  : image.width,
            );

            if (inputImage != null) {
              final result = await _scanEngine.processInputImage(
                inputImage,
                _selectedMode,
              );
              if (result.isValid &&
                  result.confidence >= options.minConfidence) {
                _emitScanDataEvent(result);
              }
            }
          } else {
            final inputImage = _inputImageFromCameraImage(image);
            if (inputImage != null) {
              final result = await _scanEngine.processInputImage(
                inputImage,
                _selectedMode,
              );
              if (result.isValid &&
                  result.confidence >= options.minConfidence) {
                _emitScanDataEvent(result);
              }
            }
          }
        } catch (_) {
          // Silently skip unparseable transient frame
        } finally {
          _isProcessingLiveFrame = false;
        }
      });
    } catch (e) {
      debugPrint('Error starting live image stream: $e');
    }
  }

  void _updateLuminosityState(double luminosity, bool lowLight) {
    _currentLuminosity = luminosity;
    if (_isLowLight != lowLight) {
      _isLowLight = lowLight;
      _lowLightController.add(lowLight);
      onLowLightDetected?.call(lowLight);
      notifyListeners();
    }
  }

  InputImage? _inputImageFromBytes(
    Uint8List bytes,
    int width,
    int height,
    int bytesPerRow,
  ) {
    if (_cameraController == null || _availableCameras.isEmpty) return null;
    final camera = _availableCameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = defaultTargetPlatform == TargetPlatform.android
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(cam.CameraImage image) {
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

  Uint8List _convertCameraImageToBytes(cam.CameraImage image) {
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
    for (final cam.Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  /// Trigger tap-to-focus on camera preview coordinates.
  Future<void> tapToFocus(Offset relativePoint) async {
    _lastTapFocusPoint = relativePoint;
    notifyListeners();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFocusPoint(relativePoint);
        await _cameraController!.setFocusMode(cam.FocusMode.auto);
      } catch (e) {
        debugPrint('Tap to focus failed: $e');
      }
    }
  }

  /// Sets absolute camera digital zoom level.
  Future<void> setZoomLevel(double zoom) async {
    final clampedZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel);
    _currentZoomLevel = clampedZoom;
    notifyListeners();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setZoomLevel(clampedZoom);
      } catch (e) {
        debugPrint('Set zoom failed: $e');
      }
    }
  }

  /// Auto-zooms by multiplier when small barcodes are far away.
  Future<void> autoZoomTo(double targetZoom) async {
    if (options.enableAutoZoom) {
      await setZoomLevel(targetZoom);
    }
  }

  /// Sets active scan mode.
  void setMode(ScanMode mode) {
    if (_selectedMode != mode) {
      _selectedMode = mode;
      notifyListeners();
    }
  }

  /// Pauses processing live stream image frames.
  void pauseScanning() {
    _isPaused = true;
    notifyListeners();
  }

  /// Resumes processing live stream image frames.
  void resumeScanning() {
    _isPaused = false;
    notifyListeners();
  }

  /// Toggles camera flash (torch mode / off).
  Future<void> toggleFlash() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _isFlashOn = !_isFlashOn;
      await _cameraController!.setFlashMode(
        _isFlashOn ? cam.FlashMode.torch : cam.FlashMode.off,
      );
      notifyListeners();
    }
  }

  /// Sets explicit flash mode.
  Future<void> setFlashMode(cam.FlashMode mode) async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.setFlashMode(mode);
      _isFlashOn =
          (mode == cam.FlashMode.torch || mode == cam.FlashMode.always);
      notifyListeners();
    }
  }

  /// Switches to next available camera.
  Future<void> switchCamera() async {
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
      _isInitialized = false;
      notifyListeners();

      await initialize();
    }
  }

  /// Clears accumulated batch inventory scan list.
  void clearBatch() {
    _batchResults.clear();
    notifyListeners();
  }

  /// Removes an item from batch scan list by index.
  void removeBatchItem(int index) {
    if (index >= 0 && index < _batchResults.length) {
      _batchResults.removeAt(index);
      notifyListeners();
    }
  }

  /// Opens gallery image picker and scans selected image file.
  Future<ScanResult?> pickAndScanImage({ScanMode? mode}) async {
    final targetMode = mode ?? _selectedMode;
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (file != null) {
        return await processImageFile(file.path, mode: targetMode);
      }
    } catch (e) {
      _errorMessage = 'Gallery pick failed: ${e.toString()}';
      notifyListeners();
    }
    return null;
  }

  /// Processes an image file from a local path.
  Future<ScanResult> processImageFile(
    String imagePath, {
    ScanMode? mode,
  }) async {
    final targetMode = mode ?? _selectedMode;
    final result = await _scanEngine.processImageFile(imagePath, targetMode);
    _emitScanDataEvent(result);
    return result;
  }

  void _emitScanDataEvent(ScanResult result) {
    if (_isAnalyzingEvent) return;
    final now = DateTime.now();

    // Duplicate detection caching window filter
    if (options.enableDuplicateFilter &&
        _lastScannedPayload == result.rawValue &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < options.duplicateTimeout) {
      return;
    }

    _isAnalyzingEvent = true;
    _lastScannedPayload = result.rawValue;
    _lastScannedTime = now;
    _lastResult = result;

    if (options.scanStrategy == ScanStrategy.batch) {
      _batchResults.add(result);
    } else if (options.scanStrategy == ScanStrategy.single) {
      pauseScanning();
    }

    if (!_scanEventController.isClosed) {
      _scanEventController.add(result);
    }
    onResultDetected?.call(result);
    notifyListeners();

    _isAnalyzingEvent = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController?.stopImageStream();
    }
    _scanEventController.close();
    _lowLightController.close();
    _cameraController?.dispose();
    _scanEngine.dispose();
    super.dispose();
  }
}
