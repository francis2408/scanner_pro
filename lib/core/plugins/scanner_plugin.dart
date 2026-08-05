import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../models/scan_result.dart';
import '../models/scanner_mode.dart';

/// Abstract plugin contract enabling custom vision recognizers, OCR models,
/// and AI parsers to be dynamically registered into [UniversalScanEngine].
abstract class ScannerPlugin {
  /// Unique identifier of this plugin recognizer.
  String get id;

  /// Human-readable title for UI selector tabs.
  String get title;

  /// Associated scan mode supported by this plugin.
  ScanMode get supportedMode;

  /// Initializes underlying vision model resources.
  Future<void> initialize();

  /// Processes an [InputImage] frame buffer or file and returns a structured [ScanResult].
  Future<ScanResult?> processInputImage(InputImage inputImage);

  /// Closes active recognizer resources.
  Future<void> dispose();
}

/// Central registry managing custom active scanner plugins.
class ScannerPluginRegistry {
  static final Map<String, ScannerPlugin> _registeredPlugins = {};

  /// Registers a new [ScannerPlugin].
  static void register(ScannerPlugin plugin) {
    _registeredPlugins[plugin.id] = plugin;
  }

  /// Unregisters a plugin by its ID.
  static void unregister(String pluginId) {
    _registeredPlugins.remove(pluginId);
  }

  /// Retrieves a registered plugin matching the specified [ScanMode].
  static ScannerPlugin? findForMode(ScanMode mode) {
    for (final plugin in _registeredPlugins.values) {
      if (plugin.supportedMode == mode) {
        return plugin;
      }
    }
    return null;
  }

  /// List of all currently registered plugin instances.
  static List<ScannerPlugin> get allPlugins =>
      List.unmodifiable(_registeredPlugins.values);

  /// Clears all registered plugins.
  static void clear() {
    _registeredPlugins.clear();
  }
}
