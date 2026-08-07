// Core models
export 'core/models/barcode_format.dart';
export 'core/models/camera_facing.dart';
export 'core/models/frame_pipeline_config.dart';
export 'core/models/ocr_text_result.dart';
export 'core/models/scan_result.dart';
export 'core/models/scanner_mode.dart';
export 'core/models/scanner_options.dart';
export 'core/models/scanner_stats.dart';
export 'core/models/scanner_theme.dart';

// Core engines (v3.0)
export 'core/engine/auto_capture_state_machine.dart';
export 'core/engine/auto_zoom_controller.dart';
export 'core/engine/barcode_decoder_engine.dart';
export 'core/engine/canny_edge_detector.dart';
export 'core/engine/contour_detector.dart';
export 'core/engine/document_detector_engine.dart';
export 'core/engine/image_preprocessing_engine.dart';
export 'core/engine/noise_reduction_engine.dart';
export 'core/engine/perspective_transform_engine.dart';

// Core interfaces (v3.0)
export 'core/interfaces/frame_preprocessor.dart';
export 'core/interfaces/result_parser.dart';
export 'core/interfaces/scan_detector.dart';

// Core processors (v3.0)
export 'core/processors/isolate_pool.dart';
export 'core/processors/ocr_text_merger.dart';
export 'core/processors/result_post_processor.dart';

// Parsers
export 'core/parsers/aadhaar_parser.dart';
export 'core/parsers/bank_cheque_parser.dart';
export 'core/parsers/business_card_parser.dart';
export 'core/parsers/driving_license_parser.dart';
export 'core/parsers/face_scanner_parser.dart';
export 'core/parsers/gs1_barcode_parser.dart';
export 'core/parsers/invoice_parser.dart';
export 'core/parsers/mrz_passport_parser.dart';
export 'core/parsers/pan_card_parser.dart';
export 'core/parsers/receipt_parser.dart';
export 'core/parsers/vin_parser.dart';

// Plugins
export 'core/plugins/scanner_plugin.dart';

// Services
export 'core/services/cloud_sync_helper.dart';
export 'core/services/csv_exporter.dart';
export 'core/services/document_classifier.dart';
export 'core/services/document_page.dart';
export 'core/services/document_scan_session.dart';
export 'core/services/document_scanner_service.dart';
export 'core/services/encrypted_storage.dart';
export 'core/services/feedback_service.dart';
export 'core/services/image_compressor.dart';
export 'core/services/json_exporter.dart';
export 'core/services/multi_scan_session.dart';
export 'core/services/pdf_exporter.dart';
export 'core/services/scan_history_controller.dart';
export 'core/services/scan_quality_analyzer.dart';
export 'core/services/scan_watermark.dart';
export 'core/services/scanner_analytics.dart';
export 'core/services/scanner_benchmark.dart';

// Service layer
export 'services/external_lookup_service.dart';
export 'services/isolate_frame_processor.dart';
export 'services/mobile_scanner_compat.dart';
export 'services/sample_card_presets.dart';
export 'services/scanbot_sdk_compat.dart';
export 'services/scanner_controller.dart';
export 'services/universal_scan_engine.dart';

// UI
export 'ui/widgets/result_bottom_sheet.dart';
export 'ui/widgets/scanner_camera_preview.dart';
export 'ui/widgets/scanner_overlay_painter.dart';
export 'ui/widgets/universal_scanner_view.dart';

// Validators & Facades
export 'core/validators/result_validator.dart';
export 'scannerpro_facade.dart';
export 'scanner_face.dart';
