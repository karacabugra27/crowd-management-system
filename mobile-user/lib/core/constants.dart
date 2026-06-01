/// Endpoint path catalogue for the Crowdly backend.
///
/// The base URL lives in [ApiConfig] (runtime-mutable, SharedPreferences-backed)
/// — this class only owns paths so the rest of the app stays unchanged when the
/// backend host moves.
class ApiPaths {
  ApiPaths._();

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

  static String wsOccupancy({int? areaId}) =>
      areaId == null ? '/ws/occupancy' : '/ws/occupancy?area_id=$areaId';
}
