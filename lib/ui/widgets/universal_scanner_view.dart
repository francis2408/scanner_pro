import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/scan_result.dart';
import '../../core/models/scanner_mode.dart';
import '../../core/models/scanner_options.dart';
import '../../core/models/scanner_theme.dart';
import '../../services/scanner_controller.dart';
import 'result_bottom_sheet.dart';
import 'scanner_camera_preview.dart';
import 'scanner_overlay_painter.dart';

/// Builder signature for creating custom screen designs with [UniversalScannerView.builder].
typedef UniversalScannerBuilder = Widget Function(
  BuildContext context,
  ScannerController controller,
  Widget cameraPreview,
);

/// Main camera viewfinder widget supporting mode switching, gallery picks, reticle overlays,
/// and complete screen layout customization.
class UniversalScannerView extends StatefulWidget {
  /// Optional custom controller for standalone functionality and state management.
  final ScannerController? controller;

  /// Optional builder for rendering custom screen designs and UI layouts.
  final UniversalScannerBuilder? builder;

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

  /// Whether Document Scanner mode is enabled.
  final bool enableDocument;

  /// Whether Invoice OCR mode is enabled.
  final bool enableInvoice;

  /// Whether Receipt OCR mode is enabled.
  final bool enableReceipt;

  /// Whether Business Card mode is enabled.
  final bool enableBusinessCard;

  /// Whether Multi-Code scanning mode is enabled.
  final bool enableMultiCode;

  /// Whether Bank Cheque MICR mode is enabled.
  final bool enableCheque;

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

  /// Whether to automatically show [ResultBottomSheet] upon scanning a valid result.
  final bool autoShowResultBottomSheet;

  /// Optional builder signature for creating custom overlay widgets.
  final Widget Function(BuildContext context, ScannerController controller)? overlayBuilder;

  /// Optional callback invoked when a valid [ScanResult] is detected.
  final Function(ScanResult result)? onResultDetected;

  /// Constructs a new [UniversalScannerView] with default pre-packaged SDK layout.
  const UniversalScannerView({
    super.key,
    this.controller,
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
    this.enableDocument = true,
    this.enableInvoice = true,
    this.enableReceipt = true,
    this.enableBusinessCard = true,
    this.enableMultiCode = true,
    this.enableCheque = true,
    this.theme,
    this.primaryAccentColor,
    this.backgroundColor,
    this.modeSelectorBackgroundColor,
    this.overlayMaskColor,
    this.laserBeamColor,
    this.showModeBadge,
    this.showGuideBox,
    this.showLaserBeam,
    this.autoShowResultBottomSheet = true,
    this.onResultDetected,
    this.overlayBuilder,
  }) : builder = null;

  /// Constructs a [UniversalScannerView] using a custom builder to create a custom screen design.
  const UniversalScannerView.builder({
    super.key,
    required this.builder,
    this.controller,
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
    this.enableDocument = true,
    this.enableInvoice = true,
    this.enableReceipt = true,
    this.enableBusinessCard = true,
    this.enableMultiCode = true,
    this.enableCheque = true,
    this.theme,
    this.primaryAccentColor,
    this.backgroundColor,
    this.modeSelectorBackgroundColor,
    this.overlayMaskColor,
    this.laserBeamColor,
    this.showModeBadge,
    this.showGuideBox,
    this.showLaserBeam,
    this.autoShowResultBottomSheet = true,
    this.onResultDetected,
    this.overlayBuilder,
  });

  /// Resolves effective [ScannerUiTheme] merging [theme] and individual color overrides.
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

  /// Resolves active scanning modes enabled for this widget.
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
    if (enableDocument) modes.add(ScanMode.document);
    if (enableInvoice) modes.add(ScanMode.invoice);
    if (enableReceipt) modes.add(ScanMode.receipt);
    if (enableBusinessCard) modes.add(ScanMode.businessCard);
    if (enableMultiCode) modes.add(ScanMode.multiCode);
    if (enableCheque) modes.add(ScanMode.cheque);

    return modes.isEmpty ? ScanMode.values : List.unmodifiable(modes);
  }

  @override
  State<UniversalScannerView> createState() => _UniversalScannerViewState();
}

class _UniversalScannerViewState extends State<UniversalScannerView>
    with SingleTickerProviderStateMixin {
  late ScannerController _controller;
  bool _createdOwnController = false;

  late final AnimationController _laserAnimController;
  StreamSubscription<ScanResult>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      final available = widget.activeEnabledModes;
      final startMode = available.contains(widget.initialMode)
          ? widget.initialMode
          : available.first;

      _controller = ScannerController(initialMode: startMode);
      _createdOwnController = true;
      _controller.initialize();
    }

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanSubscription = _controller.onResult.listen((result) {
      widget.onResultDetected?.call(result);
      if (widget.autoShowResultBottomSheet && mounted) {
        ResultBottomSheet.show(context, result);
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _laserAnimController.dispose();
    if (_createdOwnController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onSelectMode(ScanMode mode) {
    _controller.setMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.builder != null) {
      return ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return widget.builder!(
            context,
            _controller,
            ScannerCameraPreview(controller: _controller),
          );
        },
      );
    }

    final uiTheme = widget.resolvedTheme;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final currentMode = _controller.selectedMode;
        return Container(
          color: uiTheme.backgroundColor,
          child: Column(
            children: [
              _buildModeSelectorBar(currentMode),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ScannerCameraPreview(
                      controller: _controller,
                      placeholder: _buildSimulatorViewfinder(currentMode),
                    ),
                    if (widget.overlayBuilder != null)
                      widget.overlayBuilder!(context, _controller)
                    else
                      AnimatedBuilder(
                        animation: _laserAnimController,
                        builder: (context, child) {
                          final lastRes = _controller.lastResult;
                          return CustomPaint(
                            painter: ScannerOverlayPainter(
                              scanMode: currentMode,
                              animationValue: _laserAnimController.value,
                              accentColor: _getCategoryColor(currentMode.category),
                              theme: uiTheme,
                              focusPoint: _controller.lastTapFocusPoint,
                              isDetected: lastRes != null && lastRes.isValid,
                              detectedBoundingBox: lastRes?.boundingBox,
                              customScanArea: _controller.options.rectScanArea,
                              multiBoundingBoxes: lastRes?.multiResults
                                  ?.map((r) => r.boundingBox)
                                  .whereType<Rect>()
                                  .toList(),
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
                          if (_controller.isInitialized)
                            Row(
                              children: [
                                _buildIconButton(
                                  icon: _controller.isFlashOn
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  onPressed: () => _controller.toggleFlash(),
                                  active: _controller.isFlashOn,
                                  category: currentMode.category,
                                ),
                                if (_controller.isLowLight && !_controller.isFlashOn) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _controller.toggleFlash(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade800,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lightbulb_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Low Light',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (_controller.isBlurry || _controller.isMotionDetected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.shade800,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.vibration_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Hold Still',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            const SizedBox(width: 44),
                          if (uiTheme.showModeBadge)
                            _buildModeBadge(currentMode)
                          else
                            const SizedBox.shrink(),
                          Row(
                            children: [
                              if (_controller.options.scanStrategy ==
                                  ScanStrategy.batch) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(currentMode.category),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${_controller.batchResults.length} Items',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildIconButton(
                                icon: Icons.photo_library_rounded,
                                onPressed: () => _controller.pickAndScanImage(),
                                category: currentMode.category,
                              ),
                              if (_controller.availableCameras.length > 1) ...[
                                const SizedBox(width: 8),
                                _buildIconButton(
                                  icon: Icons.cameraswitch_rounded,
                                  onPressed: () => _controller.switchCamera(),
                                  category: currentMode.category,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: uiTheme.showGuideBox ? 80 : 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [1.0, 2.0, 4.0].map((zoom) {
                          final isSelected =
                              (_controller.currentZoomLevel - zoom).abs() < 0.2;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GestureDetector(
                              onTap: () => _controller.setZoomLevel(zoom),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _getCategoryColor(currentMode.category)
                                      : Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  '${zoom.toInt()}x',
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (uiTheme.showGuideBox)
                      Positioned(
                        bottom: 24,
                        left: 16,
                        right: 80,
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
                                color: _getCategoryColor(currentMode.category),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  currentMode.guideText,
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
      },
    );
  }

  Widget _buildModeSelectorBar(ScanMode currentMode) {
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
          final isSelected = mode == currentMode;
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

  Widget _buildSimulatorViewfinder(ScanMode currentMode) {
    final uiTheme = widget.resolvedTheme;
    return Container(
      color: uiTheme.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              currentMode.icon,
              size: 64,
              color: _getCategoryColor(
                currentMode.category,
              ).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '${currentMode.title} Scanner Viewfinder',
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

  Widget _buildModeBadge(ScanMode currentMode) {
    final uiTheme = widget.resolvedTheme;
    final badgeColor =
        uiTheme.badgeTextColor ?? _getCategoryColor(currentMode.category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: uiTheme.badgeBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        currentMode.title.toUpperCase(),
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
    required String category,
    bool active = false,
  }) {
    final accent = _getCategoryColor(category);
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
