/// Density levels for occupancy classification.
enum DensityLevel {
  low,     // 0–50%
  medium,  // 50–75%
  high,    // 75–90%
  critical // 90–100%
}

/// Represents a registered monitoring location (listening base).
/// Each location tracks Bluetooth device counts against a defined capacity.
class MonitoringLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int maxCapacity;
  int currentDeviceCount;
  bool isScanning;
  final DateTime createdAt;

  MonitoringLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.maxCapacity,
    this.currentDeviceCount = 0,
    this.isScanning = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Occupancy percentage (0–100), clamped to prevent overflow.
  double get occupancyPercentage =>
      maxCapacity > 0 ? (currentDeviceCount / maxCapacity * 100).clamp(0.0, 100.0) : 0.0;

  /// Categorized density level based on thresholds.
  DensityLevel get densityLevel {
    final pct = occupancyPercentage;
    if (pct >= 90) return DensityLevel.critical;
    if (pct >= 75) return DensityLevel.high;
    if (pct >= 50) return DensityLevel.medium;
    return DensityLevel.low;
  }

  /// Creates a copy with optional overrides.
  MonitoringLocation copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? maxCapacity,
    int? currentDeviceCount,
    bool? isScanning,
  }) {
    return MonitoringLocation(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentDeviceCount: currentDeviceCount ?? this.currentDeviceCount,
      isScanning: isScanning ?? this.isScanning,
      createdAt: createdAt,
    );
  }
}
