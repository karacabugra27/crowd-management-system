import 'package:flutter_test/flutter_test.dart';
import 'package:bluetooth_occupancy_admin/models/location_model.dart';

void main() {
  group('MonitoringLocation', () {
    test('occupancyPercentage calculates correctly', () {
      final location = MonitoringLocation(
        id: 'test_1',
        name: 'Test Location',
        latitude: 39.89,
        longitude: 32.86,
        maxCapacity: 100,
        currentDeviceCount: 75,
      );
      expect(location.occupancyPercentage, 75.0);
    });

    test('densityLevel returns correct level', () {
      final low = MonitoringLocation(
        id: 'test_low', name: 'Low', latitude: 0, longitude: 0,
        maxCapacity: 100, currentDeviceCount: 30,
      );
      expect(low.densityLevel, DensityLevel.low);

      final medium = MonitoringLocation(
        id: 'test_med', name: 'Medium', latitude: 0, longitude: 0,
        maxCapacity: 100, currentDeviceCount: 60,
      );
      expect(medium.densityLevel, DensityLevel.medium);

      final high = MonitoringLocation(
        id: 'test_high', name: 'High', latitude: 0, longitude: 0,
        maxCapacity: 100, currentDeviceCount: 80,
      );
      expect(high.densityLevel, DensityLevel.high);

      final critical = MonitoringLocation(
        id: 'test_crit', name: 'Critical', latitude: 0, longitude: 0,
        maxCapacity: 100, currentDeviceCount: 95,
      );
      expect(critical.densityLevel, DensityLevel.critical);
    });
  });
}
