/// api_service.dart
/// -----------------
/// Backend'e Bluetooth cihaz sayısını gönderen servis.
/// Hata durumları loglanır ve uygulama içi log listesine eklenir.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tek bir log kaydı.
class ApiLogEntry {
  final DateTime timestamp;
  final String level; // "INFO" | "WARNING" | "ERROR"
  final String message;

  ApiLogEntry({required this.level, required this.message})
      : timestamp = DateTime.now();

  @override
  String toString() =>
      '[${timestamp.toLocal().toString().substring(0, 19)}] [$level] $message';
}

/// Backend ile iletişim kuran singleton servis.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ------ Ayarlar ------
  /// Üretim için: 'http://BILGISAYAR_IP:8000'
  /// (Eğer telefon ve bilgisayar aynı Wi-Fi'daysa, bilgisayarın yerel IP'sini kullan)
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000'; // Android emülatör için
  static const String _prefsBaseUrlKey = 'api_base_url';
  static const String _prefsListenerIdKey = 'listener_id';

  String _baseUrl = _defaultBaseUrl;
  String _listenerId = 'emre-listener-01';
  bool _initialized = false;

  // ------ Log tamponu (maks 200 satır) ------
  final List<ApiLogEntry> _logs = [];
  final _logStreamController = StreamController<List<ApiLogEntry>>.broadcast();

  Stream<List<ApiLogEntry>> get logStream => _logStreamController.stream;
  List<ApiLogEntry> get logs => List.unmodifiable(_logs);

  // ------ Ayarları yükle ------
  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefsBaseUrlKey) ?? _defaultBaseUrl;
    _listenerId = prefs.getString(_prefsListenerIdKey) ?? 'emre-listener-01';
    _initialized = true;
    _log('INFO', 'ApiService başlatıldı | baseUrl=$_baseUrl | listenerId=$_listenerId');
  }

  Future<void> saveSettings({String? baseUrl, String? listenerId}) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      _baseUrl = baseUrl;
      await prefs.setString(_prefsBaseUrlKey, baseUrl);
    }
    if (listenerId != null) {
      _listenerId = listenerId;
      await prefs.setString(_prefsListenerIdKey, listenerId);
    }
    _log('INFO', 'Ayarlar güncellendi | baseUrl=$_baseUrl | listenerId=$_listenerId');
  }

  String get baseUrl => _baseUrl;
  String get listenerId => _listenerId;

  // ------ Bluetooth raporu gönder ------
  /// [areaId] : backend'deki alan ID'si (örn: 'kutuphane')
  /// [deviceCount] : algılanan Bluetooth cihaz sayısı
  ///
  /// Başarı durumunda `true`, hata durumunda `false` döner.
  Future<bool> sendBluetoothReport({
    required String areaId,
    required int deviceCount,
  }) async {
    final url = Uri.parse('$_baseUrl/api/bluetooth/report');
    final body = jsonEncode({
      'area_id': areaId,
      'device_count': deviceCount,
      'listener_id': _listenerId,
    });

    _log('INFO', 'Rapor gönderiliyor → area=$areaId cihaz=$deviceCount');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final pct = data['occupancy_pct'] ?? 0;
        final status = data['status'] ?? '?';
        _log('INFO',
            '✅ Rapor başarılı | area=$areaId pct=${pct.toStringAsFixed(1)}% durum=$status');
        return true;
      } else {
        _log('ERROR',
            '❌ Sunucu hatası | HTTP ${response.statusCode} | area=$areaId\n   Yanıt: ${response.body}');
        return false;
      }
    } on SocketException catch (e) {
      _log('ERROR',
          '❌ Bağlantı hatası (SocketException) | area=$areaId\n   Detay: $e\n   ⚠️  Backend URL doğru mu? ($_baseUrl)');
      return false;
    } on TimeoutException {
      _log('WARNING',
          '⏱️ Zaman aşımı (10s) | area=$areaId | Backend yanıt vermiyor');
      return false;
    } on FormatException catch (e) {
      _log('ERROR', '❌ JSON ayrıştırma hatası | area=$areaId\n   Detay: $e');
      return false;
    } catch (e, stack) {
      _log('ERROR',
          '❌ Beklenmeyen hata | area=$areaId\n   Detay: $e\n   Stack: $stack');
      return false;
    }
  }

  // ------ Alan listesini al ------
  Future<List<Map<String, dynamic>>> fetchAreas() async {
    final url = Uri.parse('$_baseUrl/api/bluetooth/areas');
    _log('INFO', 'Alan listesi alınıyor...');
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final areas = (jsonDecode(response.body) as List)
            .cast<Map<String, dynamic>>();
        _log('INFO', '✅ ${areas.length} alan alındı');
        return areas;
      } else {
        _log('ERROR', '❌ Alan listesi alınamadı | HTTP ${response.statusCode}');
        return [];
      }
    } on SocketException {
      _log('ERROR', '❌ Bağlantı hatası — backend erişilemiyor ($_baseUrl)');
      return [];
    } on TimeoutException {
      _log('WARNING', '⏱️ Alan listesi zaman aşımı');
      return [];
    } catch (e) {
      _log('ERROR', '❌ Alan listesi hata: $e');
      return [];
    }
  }

  // ------ Yardımcı: log ekle ------
  void _log(String level, String message) {
    final entry = ApiLogEntry(level: level, message: message);
    _logs.add(entry);
    if (_logs.length > 200) _logs.removeAt(0);
    _logStreamController.add(List.unmodifiable(_logs));
    // Dart stdout'a da yaz
    // ignore: avoid_print
    print('[ApiService] ${entry.toString()}');
  }

  void clearLogs() {
    _logs.clear();
    _logStreamController.add([]);
  }

  void dispose() {
    _logStreamController.close();
  }
}
