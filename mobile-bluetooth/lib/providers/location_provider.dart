import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/scan_uploader.dart';

/// A single detected Bluetooth device entry.
class DiscoveredDevice {
  final String macAddress;
  final String name;
  final int rssi;
  final DateTime discoveredAt;

  DiscoveredDevice({
    required this.macAddress,
    required this.name,
    required this.rssi,
    required this.discoveredAt,
  });
}

/// State manager for Bluetooth scanning (BLE + Classic dual-band).
///
/// Manages a single active area — the area is configured in settings and
/// identified by area_id/area_name from the backend. This provider does NOT
/// create or list areas locally; that is handled by the admin panel.
class LocationProvider extends ChangeNotifier {
  final Map<String, DiscoveredDevice> _globalDeviceCache = {};

  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  StreamSubscription<BluetoothDiscoveryResult>? _classicScanSubscription;

  bool _isScanning = false;
  ScanUploader? _uploader;

  bool get isScanning => _isScanning;

  /// Number of unique devices seen within the last 2 minutes.
  int get liveDeviceCount => _globalDeviceCache.values
      .where((d) => DateTime.now().difference(d.discoveredAt).inMinutes < 2)
      .length;

  /// All discovered device entries (sorted by signal strength, newest first).
  List<DiscoveredDevice> get discoveredDevices {
    final active = _globalDeviceCache.values
        .where((d) => DateTime.now().difference(d.discoveredAt).inMinutes < 2)
        .toList();
    active.sort((a, b) => b.rssi.compareTo(a.rssi));
    return active;
  }

  /// Snapshot of all MAC addresses in the cache — passed to [ScanUploader].
  List<String> get currentMacAddresses =>
      _globalDeviceCache.keys.toList(growable: false);

  /// Wire the backend uploader so it starts/stops with scanning.
  void attachUploader(ScanUploader uploader) {
    _uploader = uploader;
  }

  /// Call once on app start to subscribe to BLE scan results.
  void initialize() {
    _initBleListener();
  }

  void _initBleListener() {
    _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;
      bool updated = false;

      for (final r in results) {
        final mac = r.device.remoteId.str;
        final bleName = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : 'Unknown Device';

        final existing = _globalDeviceCache[mac];
        final resolvedName =
            (existing != null && existing.name != 'Unknown Device' && bleName == 'Unknown Device')
                ? existing.name
                : bleName;

        _globalDeviceCache[mac] = DiscoveredDevice(
          macAddress: mac,
          name: resolvedName,
          rssi: r.rssi,
          discoveredAt: DateTime.now(),
        );
        updated = true;
      }

      if (updated) notifyListeners();
    });
  }

  void _startClassicDiscoveryLoop() {
    _classicScanSubscription?.cancel();
    try {
      _classicScanSubscription =
          FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) {
          final mac = result.device.address;
          final classicName = result.device.name ?? 'Unknown Device';
          final existing = _globalDeviceCache[mac];
          final resolvedName = (classicName != 'Unknown Device')
              ? classicName
              : (existing?.name ?? 'Unknown Device');

          _globalDeviceCache[mac] = DiscoveredDevice(
            macAddress: mac,
            name: resolvedName,
            rssi: result.rssi,
            discoveredAt: DateTime.now(),
          );
          notifyListeners();
        },
        onDone: () {
          if (_isScanning) _startClassicDiscoveryLoop();
        },
      );
    } catch (e) {
      debugPrint('Classic BT Error: $e');
    }
  }

  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    if (!FlutterBluePlus.isScanningNow) {
      try {
        await FlutterBluePlus.startScan(continuousUpdates: true);
      } catch (e) {
        debugPrint('BLE Scan Error: $e');
      }
    }
    _startClassicDiscoveryLoop();
    _uploader?.start();
  }

  Future<void> stopScanning() async {
    if (!_isScanning) return;
    _isScanning = false;
    notifyListeners();

    try {
      await FlutterBluePlus.stopScan();
      _classicScanSubscription?.cancel();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }
    _uploader?.stop();
  }

  @override
  void dispose() {
    _bleScanSubscription?.cancel();
    _classicScanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
