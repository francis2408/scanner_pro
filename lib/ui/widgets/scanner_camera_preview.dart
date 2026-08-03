import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/scanner_controller.dart';

/// A lightweight, unopinionated camera preview widget for [ScannerController].
/// Renders ONLY the camera feed (or a custom placeholder) allowing developers to build custom UI overlays and screen layouts.
class ScannerCameraPreview extends StatelessWidget {
  /// Active [ScannerController] managing camera feed.
  final ScannerController controller;

  /// Custom placeholder widget rendered when camera is uninitialized or on desktop/simulator.
  final Widget? placeholder;

  /// Custom child widget layered directly on top of the camera feed.
  final Widget? child;

  /// BoxFit style for camera aspect ratio.
  final BoxFit fit;

  /// Constructs a [ScannerCameraPreview].
  const ScannerCameraPreview({
    super.key,
    required this.controller,
    this.placeholder,
    this.child,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isInitialized &&
            controller.cameraController != null &&
            controller.cameraController!.value.isInitialized) {
          final cameraWidget = CameraPreview(controller.cameraController!);
          return Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: fit,
                child: SizedBox(
                  width: controller.cameraController!.value.previewSize?.height ?? 100,
                  height: controller.cameraController!.value.previewSize?.width ?? 100,
                  child: cameraWidget,
                ),
              ),
              if (child != null) child!,
            ],
          );
        }

        return placeholder ?? _defaultSimulatorViewfinder(context);
      },
    );
  }

  Widget _defaultSimulatorViewfinder(BuildContext context) {
    return Container(
      color: const Color(0xFF090D12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.cyan.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.linked_camera_rounded,
                size: 48,
                color: Colors.cyan,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CAMERA PREVIEW ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              controller.errorMessage ?? 'Simulated sensor output / ready for stream',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
