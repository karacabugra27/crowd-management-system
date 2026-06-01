import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent configuration for the Crowdly backend integration.
///
/// Stores the backend URL, scanner API key, the area ID this device reports
/// for, and the upload interval. Values are persisted in SharedPreferences so
/// the user only configures them once.
class ApiConfig extends ChangeNotifier {
  static const _kBaseUrl = 'crowdly.baseUrl';
  static const _kApiKey = 'crowdly.apiKey';
  static const _kAreaId = 'crowdly.areaId';
  static const _kIntervalSec = 'crowdly.uploadIntervalSec';
  static const _kEnabled = 'crowdly.uploadEnabled';

  static const _defaultBaseUrl = 'http://10.0.2.2:8000';
  static const _defaultIntervalSec = 15;

  String _baseUrl = _defaultBaseUrl;
  String _apiKey = '';
  int? _areaId;
  int _intervalSec = _defaultIntervalSec;
  bool _uploadEnabled = false;
  bool _loaded = false;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  int? get areaId => _areaId;
  int get intervalSec => _intervalSec;
  bool get uploadEnabled => _uploadEnabled;
  bool get loaded => _loaded;

  /// Returns true only when every required field is set so uploads can run.
  bool get isComplete =>
      _baseUrl.trim().isNotEmpty &&
      _apiKey.trim().isNotEmpty &&
      _areaId != null &&
      _areaId! > 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_kBaseUrl) ?? _defaultBaseUrl;
    _apiKey = prefs.getString(_kApiKey) ?? '';
    _areaId = prefs.getInt(_kAreaId);
    _intervalSec = prefs.getInt(_kIntervalSec) ?? _defaultIntervalSec;
    _uploadEnabled = prefs.getBool(_kEnabled) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> update({
    String? baseUrl,
    String? apiKey,
    int? areaId,
    int? intervalSec,
    bool? uploadEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      await prefs.setString(_kBaseUrl, _baseUrl);
    }
    if (apiKey != null) {
      _apiKey = apiKey.trim();
      await prefs.setString(_kApiKey, _apiKey);
    }
    if (areaId != null) {
      _areaId = areaId;
      await prefs.setInt(_kAreaId, areaId);
    }
    if (intervalSec != null) {
      _intervalSec = intervalSec.clamp(5, 600);
      await prefs.setInt(_kIntervalSec, _intervalSec);
    }
    if (uploadEnabled != null) {
      _uploadEnabled = uploadEnabled;
      await prefs.setBool(_kEnabled, _uploadEnabled);
    }
    notifyListeners();
  }
}
