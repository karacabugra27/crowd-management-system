import '../models/location_model.dart';

/// Pre-seeded mock data.
/// Location list is now empty to support real GPS coordinates from the user's device.
class MockData {
  MockData._();

  static List<MonitoringLocation> getLocations() {
    // Return empty list so the map centers on the user's real GPS location
    return [];
  }

  /// Simulated MAC addresses for device discovery log.
  static const List<String> mockMacAddresses = [
    'A4:83:E7:2F:1B:9D',
    'B8:27:EB:3C:45:A1',
    'DC:A6:32:7E:8F:C2',
    'E4:5F:01:92:D3:5B',
    'F0:18:98:4A:BC:6E',
    '00:1A:7D:DA:71:13',
    '1C:BF:CE:15:62:8D',
    '28:6C:07:A9:F4:37',
    '34:02:86:5D:E0:CB',
    '40:B4:CD:81:23:7F',
    '5C:CF:7F:6B:94:A8',
    '68:C6:3A:D7:50:E5',
    '74:DA:38:2C:BF:19',
    '80:E6:50:E3:41:6C',
    '9C:B6:D0:97:78:AD',
    'A8:03:2A:F5:0E:D4',
    'B4:E6:2D:3B:C9:82',
    'C0:EE:FB:69:14:56',
    'CC:50:E3:A7:DB:30',
    'D8:A0:1D:5E:67:F9',
  ];

  /// Simulated device names for discovery log.
  static const List<String> mockDeviceNames = [
    'iPhone 15 Pro',
    'Galaxy S24',
    'Pixel 9',
    'MacBook Air',
    'AirPods Pro',
    'Galaxy Buds',
    'Unknown Device',
    'Mi Band 8',
    'Apple Watch',
    'Surface Laptop',
    'ThinkPad X1',
    'iPad Air',
    'Galaxy Tab',
    'Bose QC45',
    'JBL Flip 6',
    'Sony WH-1000XM5',
    'HP Spectre',
    'Dell XPS 13',
    'Fitbit Sense',
    'Nintendo Switch',
  ];
}
