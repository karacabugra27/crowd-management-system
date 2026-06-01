import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime-mutable backend configuration for the Crowdly mobile app.
///
/// Persists the API base URL in `SharedPreferences` so the user can point the
/// app at a different backend without recompiling.
///
/// On web the default is the empty string (same-origin), so nginx in front of
/// the Flutter bundle can proxy `/api` and `/ws`. On native (Android emulator
/// in particular) the default is the standard `10.0.2.2` loopback alias.
class ApiConfig extends ChangeNotifier {
  static const _kBaseUrl = 'crowdly.user.baseUrl';

  /// Platform-appropriate default URL.
  static String get defaultBaseUrl => kIsWeb ? '' : 'http://10.0.2.2:8000';

  String _baseUrl = defaultBaseUrl;
  bool _loaded = false;

  String get baseUrl => _baseUrl;
  bool get loaded => _loaded;

  /// Absolute WebSocket origin. Falls back to the current page origin on web
  /// when no override is configured — `WebSocketChannel.connect` rejects
  /// relative URIs.
  String get wsBaseUrl {
    if (_baseUrl.isEmpty) {
      if (kIsWeb) {
        final loc = Uri.base;
        final scheme = loc.scheme == 'https' ? 'wss' : 'ws';
        final port = loc.hasPort ? ':${loc.port}' : '';
        return '$scheme://${loc.host}$port';
      }
      // Native fallback (shouldn't normally happen — load() always populates).
      return 'ws://10.0.2.2:8000';
    }
    return _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned == _baseUrl) return;
    _baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, cleaned);
    notifyListeners();
  }

  Future<void> reset() => setBaseUrl(defaultBaseUrl);
}
