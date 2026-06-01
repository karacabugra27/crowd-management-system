import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_config.dart';
import 'backend_service.dart';

/// Status of the most recent upload attempt.
enum UploadState { idle, uploading, success, error }

/// Periodically pushes the currently visible MAC list to the Crowdly backend.
///
/// Owns its own [Timer]; start/stop are explicit so the uploader only runs
/// while a Bluetooth scan is active and the user has enabled syncing.
class ScanUploader extends ChangeNotifier {
  ScanUploader({
    required ApiConfig config,
    required Iterable<String> Function() macSnapshot,
  })  : _config = config,
        _macSnapshot = macSnapshot,
        _service = BackendService(config);

  final ApiConfig _config;
  final Iterable<String> Function() _macSnapshot;
  final BackendService _service;

  Timer? _timer;
  UploadState _state = UploadState.idle;
  String? _lastError;
  int? _lastDeviceCount;
  double? _lastOccupancyPct;
  String? _lastStatus;
  DateTime? _lastSyncedAt;
  bool _running = false;

  UploadState get state => _state;
  String? get lastError => _lastError;
  int? get lastDeviceCount => _lastDeviceCount;
  double? get lastOccupancyPct => _lastOccupancyPct;
  String? get lastStatus => _lastStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isRunning => _running;

  void start() {
    if (_running) return;
    if (!_config.uploadEnabled) return;
    if (!_config.isComplete) {
      _setError('Yapılandırma eksik. Lütfen ayarlardan kontrol edin.');
      return;
    }

    _running = true;
    notifyListeners();

    // Fire once immediately, then on a fixed interval.
    _flush();
    _timer = Timer.periodic(
      Duration(seconds: _config.intervalSec),
      (_) => _flush(),
    );
  }

  void stop() {
    if (!_running) return;
    _timer?.cancel();
    _timer = null;
    _running = false;
    _state = UploadState.idle;
    notifyListeners();
  }

  Future<void> sendOnce() => _flush();

  Future<void> _flush() async {
    if (!_config.isComplete) {
      _setError('Yapılandırma eksik. Lütfen ayarları kontrol edin.');
      return;
    }
    _state = UploadState.uploading;
    notifyListeners();

    final macs = _macSnapshot();
    final result = await _service.submitScan(macs);

    if (result.success) {
      _state = UploadState.success;
      _lastError = null;
      _lastDeviceCount = result.deviceCount;
      _lastOccupancyPct = result.occupancyPct;
      _lastStatus = result.status;
      _lastSyncedAt = DateTime.now();
    } else {
      _setError(result.error ?? 'Bilinmeyen hata.');
    }
    notifyListeners();
  }

  void _setError(String message) {
    _state = UploadState.error;
    _lastError = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }
}
