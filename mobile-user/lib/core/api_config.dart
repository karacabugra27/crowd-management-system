import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime-mutable backend configuration for the Crowdly mobile app.
///
/// Persists the API base URL in `SharedPreferences` so the user can point the
/// app at a different backend (LAN IP, staging, production) without recompiling.
class ApiConfig extends ChangeNotifier {
  static const _kBaseUrl = 'crowdly.user.baseUrl';

  /// Sensible default for an Android emulator running against a local backend.
  /// Real-device users override this from the in-app settings screen.
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';

  String _baseUrl = defaultBaseUrl;
  bool _loaded = false;

  String get baseUrl => _baseUrl;
  String get wsBaseUrl => _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty || cleaned == _baseUrl) return;
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, cleaned);
    notifyListeners();
  }

  Future<void> reset() => setBaseUrl(defaultBaseUrl);
}
