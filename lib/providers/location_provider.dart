import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/location_model.dart';
import '../services/mock_data.dart';

/// Discovered device entry for the scanning log.
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

/// Central state manager for all monitoring locations.
/// Uses REAL hardware Dual-Band (BLE + Classic) Bluetooth scanning.
class LocationProvider extends ChangeNotifier {
  List<MonitoringLocation> _locations = [];
  final Map<String, List<DiscoveredDevice>> _discoveredDevices = {};
  
  // Track which locations are currently set to "Scanning"
  final Set<String> _scanningLocationIds = {};
  
  // Unified cache for all discovered devices (keyed by MAC)
  final Map<String, DiscoveredDevice> _globalDeviceCache = {};
  
  // Real Bluetooth subscriptions
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  StreamSubscription<BluetoothDiscoveryResult>? _classicScanSubscription;
  
  bool _isLoading = true;

  List<MonitoringLocation> get locations => List.unmodifiable(_locations);
  bool get isLoading => _isLoading;

  int get totalDevices =>
      _locations.fold(0, (sum, loc) => sum + loc.currentDeviceCount);

  double get averageOccupancy {
    if (_locations.isEmpty) return 0;
    return _locations.fold(0.0, (sum, loc) => sum + loc.occupancyPercentage) /
        _locations.length;
  }

  List<DiscoveredDevice> getDiscoveredDevices(String locationId) {
    return _discoveredDevices[locationId] ?? [];
  }

  Future<void> loadLocations() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));
    _locations = MockData.getLocations();

    // Init the BLE stream listener which runs globally
    _initBleListener();

    _isLoading = false;
    notifyListeners();
  }

  void _initBleListener() {
    _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;
      bool cacheUpdated = false;
      
      for (var r in results) {
        final mac = r.device.remoteId.str;
        
        // Extract raw BLE name
        final bleName = r.device.platformName.isNotEmpty 
            ? r.device.platformName 
            : r.advertisementData.advName.isNotEmpty 
                ? r.advertisementData.advName 
                : 'Unknown Device';

        final existing = _globalDeviceCache[mac];
        
        // SMART NAME RESOLUTION:
        // If BLE sees an anonymous "Unknown Device" but our cache 
        // already has a real name from Classic BT, we keep the real name!
        final resolvedName = (existing != null && existing.name != 'Unknown Device' && bleName == 'Unknown Device')
            ? existing.name
            : bleName;

        _globalDeviceCache[mac] = DiscoveredDevice(
          macAddress: mac,
          name: resolvedName,
          rssi: r.rssi,
          discoveredAt: DateTime.now(),
        );
        cacheUpdated = true;
      }

      if (cacheUpdated) {
        _broadcastCacheToLocations();
      }
    });
  }

  void _startClassicDiscoveryLoop() {
    _classicScanSubscription?.cancel();
    
    try {
      _classicScanSubscription = FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
        final mac = result.device.address;
        // Classic BT is highly reliable for getting actual device names (e.g. "My PC")
        final classicName = result.device.name ?? 'Unknown Device';
        final rssi = result.rssi;

        final existing = _globalDeviceCache[mac];
        
        // SMART NAME RESOLUTION:
        // Classic names are prioritized over existing Unknowns
        final resolvedName = (classicName != 'Unknown Device') 
            ? classicName 
            : (existing?.name ?? 'Unknown Device');

        _globalDeviceCache[mac] = DiscoveredDevice(
          macAddress: mac,
          name: resolvedName,
          rssi: rssi,
          discoveredAt: DateTime.now(),
        );
        
        _broadcastCacheToLocations();
      }, onDone: () {
        // Classic discovery natively times out after ~12 seconds.
        // We automatically loop it if any listening base is still active.
        if (_scanningLocationIds.isNotEmpty) {
          _startClassicDiscoveryLoop();
        }
      });
    } catch (e) {
      debugPrint("Classic BT Error: $e");
    }
  }

  void _broadcastCacheToLocations() {
    if (_scanningLocationIds.isEmpty) return;

    // Filter to active devices seen in the last 2 minutes and sort by signal strength
    final activeDevices = _globalDeviceCache.values.where((d) => 
        DateTime.now().difference(d.discoveredAt).inMinutes < 2
    ).toList();
    
    activeDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
    
    // Broadcast findings to all active dashboard locations
    for (final locId in _scanningLocationIds) {
      final index = _locations.indexWhere((loc) => loc.id == locId);
      if (index == -1) continue;

      _discoveredDevices[locId] = List.from(activeDevices.take(150)); // cap at 150
      _locations[index].currentDeviceCount = activeDevices.length;
    }
    
    notifyListeners();
  }

  void addLocation(MonitoringLocation location) {
    _locations.add(location);
    notifyListeners();
  }

  MonitoringLocation? getLocation(String id) {
    try {
      return _locations.firstWhere((loc) => loc.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> startScanning(String locationId) async {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index == -1) return;

    final wasEmpty = _scanningLocationIds.isEmpty;

    _locations[index].isScanning = true;
    _scanningLocationIds.add(locationId);
    notifyListeners();

    // If this is the first location to request scanning, spin up the Dual-Band antennas
    if (wasEmpty) {
      // 1. Fire up BLE physical antenna
      if (FlutterBluePlus.isScanningNow == false) {
        try {
          await FlutterBluePlus.startScan(continuousUpdates: true);
        } catch (e) {
          debugPrint("BLE Scan Error: $e");
        }
      }
      
      // 2. Fire up Classic BT discovery loop
      _startClassicDiscoveryLoop();
    }
  }

  Future<void> stopScanning(String locationId) async {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index == -1) return;

    _locations[index].isScanning = false;
    _scanningLocationIds.remove(locationId);
    notifyListeners();

    // Power down the antennas to save battery if no bases are listening
    if (_scanningLocationIds.isEmpty) {
      try {
        await FlutterBluePlus.stopScan();
        _classicScanSubscription?.cancel();
      } catch (e) {
        debugPrint("Error stopping scan: $e");
      }
    }
  }

  @override
  void dispose() {
    _bleScanSubscription?.cancel();
    _classicScanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
