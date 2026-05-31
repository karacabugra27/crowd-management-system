class ApiConfig {
  // Geliştirme ortamında backend URL'si
  // Android emulator: 10.0.2.2, iOS simulator: 127.0.0.1, gerçek cihaz: bilgisayar IP'si
  static const String baseUrl = 'http://10.0.2.2:8000';

  // WebSocket URL
  static String get wsBaseUrl => baseUrl.replaceFirst('http', 'ws');

  // API endpoints
  static const String authLogin = '/api/auth/login';
  static const String authRegister = '/api/auth/register';
  static const String authRefresh = '/api/auth/refresh';

  static const String usersMe = '/api/users/me';

  static const String areas = '/api/areas/';
  static String areaById(int id) => '/api/areas/$id';
  static String areaToggle(int id) => '/api/areas/$id/toggle-active';

  static const String occupancyLive = '/api/occupancy/live';
  static String occupancyLiveOne(int areaId) => '/api/occupancy/live/$areaId';
  static String occupancyHistory(int areaId, {int hours = 24}) =>
      '/api/occupancy/history/$areaId?hours=$hours';
  static const String occupancyHeatmap = '/api/occupancy/heatmap';
  static const String occupancySummary = '/api/occupancy/summary';

  static const String adminDashboard = '/api/admin/dashboard';
  static const String adminScanners = '/api/admin/scanners';
  static String adminScannerDelete(int id) => '/api/admin/scanners/$id';

  static String wsOccupancy({int? areaId}) {
    final base = '$wsBaseUrl/ws/occupancy';
    if (areaId != null) return '$base?area_id=$areaId';
    return base;
  }
}
