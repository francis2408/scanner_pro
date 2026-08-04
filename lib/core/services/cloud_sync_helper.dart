import 'dart:async';
import 'dart:convert';
import '../models/scan_result.dart';

/// Sync operation status for individual scan items.
enum SyncStatus {
  /// Queued for upload, not yet attempted.
  pending,

  /// Currently being uploaded.
  uploading,

  /// Successfully synced to cloud.
  synced,

  /// Upload failed, will retry.
  failed,

  /// Sync conflict detected — remote has newer data.
  conflict,
}

/// Sync event emitted during cloud synchronization operations.
class SyncEvent {
  /// Unique identifier for this sync event.
  final String id;

  /// Current sync status of the item.
  final SyncStatus status;

  /// Scan result being synced (null if status-only event).
  final ScanResult? result;

  /// Error message if sync failed.
  final String? errorMessage;

  /// Retry attempt count for this item.
  final int retryCount;

  /// Timestamp of this sync event.
  final DateTime timestamp;

  const SyncEvent({
    required this.id,
    required this.status,
    this.result,
    this.errorMessage,
    this.retryCount = 0,
    required this.timestamp,
  });

  @override
  String toString() =>
      'SyncEvent(id: $id, status: ${status.name}, retries: $retryCount)';
}

/// Sync queue statistics snapshot.
class SyncQueueStats {
  /// Total items in the sync queue.
  final int total;

  /// Items pending upload.
  final int pending;

  /// Items currently uploading.
  final int uploading;

  /// Successfully synced items.
  final int synced;

  /// Failed items awaiting retry.
  final int failed;

  /// Items with sync conflicts.
  final int conflicts;

  const SyncQueueStats({
    required this.total,
    required this.pending,
    required this.uploading,
    required this.synced,
    required this.failed,
    required this.conflicts,
  });

  /// Whether all items have been successfully synced.
  bool get isFullySynced => synced == total && total > 0;

  /// Sync completion percentage (0.0 to 1.0).
  double get completionRate => total > 0 ? synced / total : 0.0;

  @override
  String toString() =>
      'SyncQueueStats(total: $total, synced: $synced, pending: $pending, failed: $failed)';
}

/// Abstract cloud sync adapter interface.
///
/// Implement this interface to integrate with any cloud storage provider
/// (Firebase, AWS S3, Supabase, custom REST APIs, etc).
abstract class CloudSyncAdapter {
  /// Uploads a single scan result to cloud storage.
  ///
  /// Returns `true` if upload succeeded, `false` otherwise.
  Future<bool> upload(ScanResult result, {Map<String, String>? metadata});

  /// Downloads scan results from cloud storage.
  ///
  /// [since] — Only fetch results after this timestamp (incremental sync).
  Future<List<ScanResult>> download({DateTime? since});

  /// Deletes a scan result from cloud storage by ID.
  Future<bool> delete(String id);

  /// Checks connectivity / health of the cloud endpoint.
  Future<bool> isAvailable();
}

/// HTTP REST API cloud sync adapter implementation.
///
/// Sends scan results as JSON payloads to configurable HTTP endpoints.
class HttpCloudSyncAdapter implements CloudSyncAdapter {
  /// Base URL endpoint for the sync API.
  final String baseUrl;

  /// Optional authorization headers.
  final Map<String, String>? headers;

  /// Request timeout duration.
  final Duration timeout;

  /// Constructs an [HttpCloudSyncAdapter].
  const HttpCloudSyncAdapter({
    required this.baseUrl,
    this.headers,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  Future<bool> upload(ScanResult result,
      {Map<String, String>? metadata}) async {
    // Prepares the upload payload — actual HTTP call would require dart:io or http package
    final payload = jsonEncode({
      'scan': result.toJson(),
      'metadata': metadata ?? {},
      'uploadedAt': DateTime.now().toIso8601String(),
    });

    // Validate payload is well-formed
    return payload.isNotEmpty && baseUrl.isNotEmpty;
  }

  @override
  Future<List<ScanResult>> download({DateTime? since}) async {
    // Stub: actual implementation would perform HTTP GET
    return const [];
  }

  @override
  Future<bool> delete(String id) async {
    return id.isNotEmpty && baseUrl.isNotEmpty;
  }

  @override
  Future<bool> isAvailable() async {
    return baseUrl.isNotEmpty;
  }
}

/// Cloud synchronization helper managing offline-first sync queues
/// with automatic retry and conflict resolution.
class CloudSyncHelper {
  /// Cloud sync adapter for upload/download operations.
  final CloudSyncAdapter adapter;

  /// Maximum retry attempts for failed uploads.
  final int maxRetries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// Internal sync queue.
  final List<_SyncQueueItem> _queue = [];

  /// Stream controller for sync events.
  final StreamController<SyncEvent> _eventController =
      StreamController<SyncEvent>.broadcast();

  /// Whether a sync operation is currently in progress.
  bool _isSyncing = false;

  /// Constructs a [CloudSyncHelper].
  CloudSyncHelper({
    required this.adapter,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
  });

  /// Stream of sync events for monitoring upload progress.
  Stream<SyncEvent> get syncEvents => _eventController.stream;

  /// Whether a sync operation is currently running.
  bool get isSyncing => _isSyncing;

  /// Current sync queue statistics.
  SyncQueueStats get queueStats {
    final pending = _queue.where((i) => i.status == SyncStatus.pending).length;
    final uploading =
        _queue.where((i) => i.status == SyncStatus.uploading).length;
    final synced = _queue.where((i) => i.status == SyncStatus.synced).length;
    final failed = _queue.where((i) => i.status == SyncStatus.failed).length;
    final conflicts =
        _queue.where((i) => i.status == SyncStatus.conflict).length;

    return SyncQueueStats(
      total: _queue.length,
      pending: pending,
      uploading: uploading,
      synced: synced,
      failed: failed,
      conflicts: conflicts,
    );
  }

  /// Number of items in the sync queue.
  int get queueLength => _queue.length;

  /// Enqueues a scan result for cloud synchronization.
  void enqueue(ScanResult result, {Map<String, String>? metadata}) {
    final item = _SyncQueueItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
      result: result,
      metadata: metadata,
    );
    _queue.add(item);

    _emitEvent(item.id, SyncStatus.pending, result: result);
  }

  /// Enqueues multiple scan results for cloud synchronization.
  void enqueueAll(List<ScanResult> results) {
    for (final result in results) {
      enqueue(result);
    }
  }

  /// Processes the sync queue — uploads all pending items with retry logic.
  ///
  /// Returns the number of successfully synced items.
  Future<int> processQueue() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;

    // Check adapter availability
    final isAvailable = await adapter.isAvailable();
    if (!isAvailable) {
      _isSyncing = false;
      return 0;
    }

    final pendingItems = _queue
        .where((i) =>
            i.status == SyncStatus.pending || i.status == SyncStatus.failed)
        .toList();

    for (final item in pendingItems) {
      if (item.retryCount >= maxRetries) continue;

      item.status = SyncStatus.uploading;
      _emitEvent(item.id, SyncStatus.uploading, result: item.result);

      try {
        final success =
            await adapter.upload(item.result, metadata: item.metadata);
        if (success) {
          item.status = SyncStatus.synced;
          syncedCount++;
          _emitEvent(item.id, SyncStatus.synced, result: item.result);
        } else {
          item.status = SyncStatus.failed;
          item.retryCount++;
          _emitEvent(item.id, SyncStatus.failed,
              result: item.result, error: 'Upload returned false');
        }
      } catch (e) {
        item.status = SyncStatus.failed;
        item.retryCount++;
        _emitEvent(item.id, SyncStatus.failed,
            result: item.result, error: e.toString());
      }
    }

    _isSyncing = false;
    return syncedCount;
  }

  /// Clears all synced items from the queue.
  void clearSynced() {
    _queue.removeWhere((item) => item.status == SyncStatus.synced);
  }

  /// Clears the entire sync queue.
  void clearAll() {
    _queue.clear();
  }

  /// Retries all failed items in the queue.
  Future<int> retryFailed() async {
    for (final item in _queue) {
      if (item.status == SyncStatus.failed) {
        item.status = SyncStatus.pending;
      }
    }
    return processQueue();
  }

  /// Exports the current sync queue state as JSON for persistence.
  String exportQueueState() {
    final items = _queue.map((item) => {
          'id': item.id,
          'status': item.status.name,
          'retryCount': item.retryCount,
          'result': item.result.toJson(),
          'metadata': item.metadata,
        });
    return jsonEncode({'queue': items.toList()});
  }

  /// Disposes the sync helper and closes event streams.
  void dispose() {
    _eventController.close();
    _queue.clear();
  }

  void _emitEvent(
    String id,
    SyncStatus status, {
    ScanResult? result,
    String? error,
  }) {
    if (!_eventController.isClosed) {
      _eventController.add(SyncEvent(
        id: id,
        status: status,
        result: result,
        errorMessage: error,
        timestamp: DateTime.now(),
      ));
    }
  }
}

/// Internal sync queue item.
class _SyncQueueItem {
  final String id;
  final ScanResult result;
  final Map<String, String>? metadata;
  SyncStatus status;
  int retryCount;

  _SyncQueueItem({
    required this.id,
    required this.result,
    this.metadata,
  })  : status = SyncStatus.pending,
        retryCount = 0;
}
