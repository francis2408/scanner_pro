import 'dart:async';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models/scan_result.dart';
import '../core/models/scanner_mode.dart';
import 'universal_scan_engine.dart';

/// Standalone controller for managing camera lifecycle, live ML frame processing,
/// mode selection, and image file scanning without requiring a pre-built UI layout.
class ScannerController extends ChangeNotifier {
  /// Initial mode when scanner initializes.
  ScanMode _selectedMode;

  /// Resolution preset for camera controller.
  final cam.ResolutionPreset resolutionPreset;

  /// Optional callback invoked when a valid scan result is detected.
  final Function(ScanResult result)? onResultDetected;

  /// Internal scan engine for executing ML Kit vision models.
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

  bool _isAnalyzingEvent = false;
  bool _isProcessingLiveFrame = false;
  String? _lastScannedPayload;
  DateTime? _lastScannedTime;
  Uint8List? _cachedNv21Buffer;
  DateTime? _lastFrameProcessedTime;
  ScanResult? _lastResult;
  String? _errorMessage;

  /// Constructs a [ScannerController].
  ScannerController({
    ScanMode initialMode = ScanMode.qr,
    this.resolutionPreset = cam.ResolutionPreset.high,
    this.onResultDetected,
    UniversalScanEngine? scanEngine,
    ImagePicker? imagePicker,
  })  : _selectedMode = initialMode,
        _scanEngine = scanEngine ?? UniversalScanEngine(),
        _imagePicker = imagePicker ?? ImagePicker();

  /// Whether camera controller and ML engine are initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Whether camera initialization is currently in progress.
  bool get isInitializing => _isInitializing;

  /// Whether flash/torch is currently turned on.
  bool get isFlashOn => _isFlashOn;

  /// Currently selected camera index in [availableCameras].
  int get selectedCameraIndex => _selectedCameraIndex;

  /// List of available hardware cameras on device.
  List<cam.CameraDescription> get availableCameras => List.unmodifiable(_availableCameras);

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

  /// Most recently detected [ScanResult].
  ScanResult? get lastResult => _lastResult;

  /// Last error message encountered during camera or scan operations.
  String? get errorMessage => _errorMessage;

  /// Initializes hardware cameras and starts live stream processing.
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
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
      _isFlashOn = (mode == cam.FlashMode.torch || mode == cam.FlashMode.always);
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
  Future<ScanResult> processImageFile(String imagePath, {ScanMode? mode}) async {
    final targetMode = mode ?? _selectedMode;
    final result = await _scanEngine.processImageFile(imagePath, targetMode);
    _emitScanDataEvent(result);
    return result;
  }

  void _emitScanDataEvent(ScanResult result) {
    if (_isAnalyzingEvent) return;
    final now = DateTime.now();
    if (_lastScannedPayload == result.rawValue &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!) < const Duration(seconds: 4)) {
      return;
    }

    _isAnalyzingEvent = true;
    _lastScannedPayload = result.rawValue;
    _lastScannedTime = now;
    _lastResult = result;

    if (!_scanEventController.isClosed) {
      _scanEventController.add(result);
    }
    onResultDetected?.call(result);
    notifyListeners();

    _isAnalyzingEvent = false;
  }

  @override
  void dispose() {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController?.stopImageStream();
    }
    _scanEventController.close();
    _cameraController?.dispose();
    _scanEngine.dispose();
    super.dispose();
  }
}
