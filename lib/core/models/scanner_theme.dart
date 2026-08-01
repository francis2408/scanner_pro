import 'package:flutter/material.dart';

/// Customizable theme and visual design configuration for Universal Scanner Pro.
class ScannerUiTheme {
  /// Background dimming color outside the camera viewfinder cutout.
  final Color overlayMaskColor;

  /// Primary accent color for viewfinder reticle, selected mode, and highlight lines.
  final Color? accentColor;

  /// Color of reticle corner brackets.
  final Color? reticleCornerColor;

  /// Stroke color for reticle cutout outline.
  final Color? reticleBorderColor;

  /// Color of animated scanning laser beam.
  final Color? laserBeamColor;

  /// Scanner viewport container background color.
  final Color backgroundColor;

  /// Mode selection bottom bar background color.
  final Color modeSelectorBackgroundColor;

  /// Background color of selected mode pill tab.
  final Color? modeTabSelectedColor;

  /// Background color of unselected mode pill tab.
  final Color modeTabUnselectedColor;

  /// Text color of selected mode pill tab.
  final Color modeTabSelectedTextColor;

  /// Text color of unselected mode pill tab.
  final Color modeTabUnselectedTextColor;

  /// Background color of top floating guide box.
  final Color guideBoxBackgroundColor;

  /// Text color inside floating guidance box.
  final Color guideTextColor;

  /// Background color of top active mode badge chip.
  final Color badgeBackgroundColor;

  /// Text color of active mode badge chip.
  final Color? badgeTextColor;

  /// Whether to display top active mode badge chip.
  final bool showModeBadge;

  /// Whether to display top floating guidance text box.
  final bool showGuideBox;

  /// Whether to display animated scanning laser beam.
  final bool showLaserBeam;

  /// Length of reticle corner brackets.
  final double reticleCornerLength;

  /// Thickness of corner brackets.
  final double reticleCornerWidth;

  /// Thickness of reticle outline border.
  final double reticleBorderWidth;

  /// Border corner radius for rectangular cutouts.
  final double reticleCornerRadius;

  /// Constructs a new [ScannerUiTheme].
  const ScannerUiTheme({
    this.overlayMaskColor = const Color(0xA6000000),
    this.accentColor,
    this.reticleCornerColor,
    this.reticleBorderColor,
    this.laserBeamColor,
    this.backgroundColor = const Color(0xFF090D12),
    this.modeSelectorBackgroundColor = const Color(0xFF0B0E14),
    this.modeTabSelectedColor,
    this.modeTabUnselectedColor = const Color(0x0DFFFFFF),
    this.modeTabSelectedTextColor = Colors.black,
    this.modeTabUnselectedTextColor = Colors.white70,
    this.guideBoxBackgroundColor = const Color(0xBF000000),
    this.guideTextColor = Colors.white,
    this.badgeBackgroundColor = const Color(0xA6000000),
    this.badgeTextColor,
    this.showModeBadge = true,
    this.showGuideBox = true,
    this.showLaserBeam = true,
    this.reticleCornerLength = 28.0,
    this.reticleCornerWidth = 4.5,
    this.reticleBorderWidth = 2.5,
    this.reticleCornerRadius = 16.0,
  });

  /// Default dark theme preset for Scanner Pro.
  static const ScannerUiTheme dark = ScannerUiTheme();

  /// Vibrant cyan theme preset.
  static const ScannerUiTheme cyan = ScannerUiTheme(
    accentColor: Color(0xFF00E5FF),
    reticleCornerColor: Color(0xFF00E5FF),
    laserBeamColor: Color(0xFF00E5FF),
  );

  /// Emerald green theme preset.
  static const ScannerUiTheme emerald = ScannerUiTheme(
    accentColor: Color(0xFF00E676),
    reticleCornerColor: Color(0xFF00E676),
    laserBeamColor: Color(0xFF00E676),
  );

  /// Neon amber theme preset.
  static const ScannerUiTheme amber = ScannerUiTheme(
    accentColor: Color(0xFFFFD600),
    reticleCornerColor: Color(0xFFFFD600),
    laserBeamColor: Color(0xFFFFD600),
  );
}
