import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
/// Simulates Bluetooth scanning with periodic random updates.
class LocationProvider extends ChangeNotifier {
  List<MonitoringLocation> _locations = [];
  final Map<String, Timer> _scanTimers = {};
  final Map<String, List<DiscoveredDevice>> _discoveredDevices = {};
  final Random _random = Random();
  bool _isLoading = true;

  List<MonitoringLocation> get locations => List.unmodifiable(_locations);
  bool get isLoading => _isLoading;

  /// Total devices found across all locations.
  int get totalDevices =>
      _locations.fold(0, (sum, loc) => sum + loc.currentDeviceCount);

  /// Average occupancy across all locations.
  double get averageOccupancy {
    if (_locations.isEmpty) return 0;
    return _locations.fold(0.0, (sum, loc) => sum + loc.occupancyPercentage) /
        _locations.length;
  }

  /// Get discovered devices for a specific location.
  List<DiscoveredDevice> getDiscoveredDevices(String locationId) {
    return _discoveredDevices[locationId] ?? [];
  }

  /// Initialize with mock data and a simulated loading delay.
  Future<void> loadLocations() async {
    _isLoading = true;
    notifyListeners();

    // Simulate network/database loading delay
    await Future.delayed(const Duration(milliseconds: 1500));

    _locations = MockData.getLocations();

    // Start scanning for locations that are already marked as scanning
    for (final location in _locations) {
      if (location.isScanning) {
        _startScanTimer(location.id);
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new monitoring location.
  void addLocation(MonitoringLocation location) {
    _locations.add(location);
    notifyListeners();
  }

  /// Get a single location by ID.
  MonitoringLocation? getLocation(String id) {
    try {
      return _locations.firstWhere((loc) => loc.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Start simulated Bluetooth scanning for a location.
  void startScanning(String locationId) {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index == -1) return;

    _locations[index].isScanning = true;
    _startScanTimer(locationId);
    notifyListeners();
  }

  /// Stop scanning for a location.
  void stopScanning(String locationId) {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index == -1) return;

    _locations[index].isScanning = false;
    _scanTimers[locationId]?.cancel();
    _scanTimers.remove(locationId);
    notifyListeners();
  }

  /// Internal: start a periodic timer that simulates device discovery.
  void _startScanTimer(String locationId) {
    // Cancel any existing timer for this location
    _scanTimers[locationId]?.cancel();

    _scanTimers[locationId] = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _simulateScan(locationId),
    );
  }

  /// Simulate discovering/losing Bluetooth devices.
  void _simulateScan(String locationId) {
    final index = _locations.indexWhere((loc) => loc.id == locationId);
    if (index == -1) return;

    final location = _locations[index];
    if (!location.isScanning) return;

    // Randomly adjust device count: ±1 to ±3 devices
    final delta = _random.nextInt(5) - 2; // -2 to +2
    final newCount = (location.currentDeviceCount + delta)
        .clamp(0, location.maxCapacity + 5); // Allow slight overflow for realism

    _locations[index].currentDeviceCount = newCount;

    // Occasionally add a discovered device to the log
    if (delta > 0 && _random.nextBool()) {
      _addDiscoveredDevice(locationId);
    }

    notifyListeners();
  }

  /// Add a fake discovered device to the log.
  void _addDiscoveredDevice(String locationId) {
    final devices = _discoveredDevices.putIfAbsent(locationId, () => []);

    final macIndex = _random.nextInt(MockData.mockMacAddresses.length);
    final nameIndex = _random.nextInt(MockData.mockDeviceNames.length);

    devices.insert(
      0,
      DiscoveredDevice(
        macAddress: MockData.mockMacAddresses[macIndex],
        name: MockData.mockDeviceNames[nameIndex],
        rssi: -(_random.nextInt(60) + 30), // -30 to -90 dBm
        discoveredAt: DateTime.now(),
      ),
    );

    // Keep only the latest 50 entries
    if (devices.length > 50) {
      devices.removeRange(50, devices.length);
    }
  }

  @override
  void dispose() {
    // Cancel all running scan timers
    for (final timer in _scanTimers.values) {
      timer.cancel();
    }
    _scanTimers.clear();
    super.dispose();
  }
}
