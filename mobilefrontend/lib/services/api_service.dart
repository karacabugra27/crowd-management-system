import 'dart:convert';
import '../core/constants.dart';
import 'api_client.dart';

/// Auth API (web client.js authApi ile aynı endpointler)
class AuthService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _api.post(
      ApiConfig.authLogin,
      {'email': email, 'password': password},
      intercept401: false,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _api.setTokens(data['access_token'], data['refresh_token']);
      return data;
    } else {
      final err = jsonDecode(response.body);
      throw ApiException(err['detail'] ?? 'Giriş başarısız');
    }
  }

  Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await _api.post(
      ApiConfig.authRegister,
      {'email': email, 'password': password},
      intercept401: false,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _api.setTokens(data['access_token'], data['refresh_token']);
      return data;
    } else {
      final err = jsonDecode(response.body);
      throw ApiException(err['detail'] ?? 'Kayıt başarısız');
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
  }
}

/// Users API
class UsersService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> getMe() async {
    final response = await _api.get(ApiConfig.usersMe);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Kullanıcı bilgileri alınamadı');
  }
}

/// Areas API
class AreasService {
  final _api = ApiClient();

  Future<List<dynamic>> list() async {
    final response = await _api.get(ApiConfig.areas);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Alanlar alınamadı');
  }

  Future<Map<String, dynamic>> getById(int id) async {
    final response = await _api.get(ApiConfig.areaById(id));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Alan bilgisi alınamadı');
  }

  Future<void> create(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.areas, data);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw ApiException(err['detail'] ?? 'Alan oluşturulamadı');
    }
  }

  Future<void> update(int id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.areaById(id), data);
    if (response.statusCode != 200) {
      throw ApiException('Alan güncellenemedi');
    }
  }

  Future<void> toggleActive(int id) async {
    final response = await _api.patch(ApiConfig.areaToggle(id));
    if (response.statusCode != 200) {
      throw ApiException('Alan durumu değiştirilemedi');
    }
  }

  Future<void> deleteArea(int id) async {
    final response = await _api.delete(ApiConfig.areaById(id));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException('Alan silinemedi');
    }
  }
}

/// Occupancy API
class OccupancyService {
  final _api = ApiClient();

  Future<List<dynamic>> live() async {
    final response = await _api.get(ApiConfig.occupancyLive);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Canlı veriler alınamadı');
  }

  Future<Map<String, dynamic>> liveOne(int areaId) async {
    final response = await _api.get(ApiConfig.occupancyLiveOne(areaId));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Alan verisi alınamadı');
  }

  Future<List<dynamic>> history(int areaId, {int hours = 24}) async {
    final response = await _api.get(
      ApiConfig.occupancyHistory(areaId, hours: hours),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Geçmiş veriler alınamadı');
  }

  Future<List<dynamic>> heatmap() async {
    final response = await _api.get(ApiConfig.occupancyHeatmap);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Heatmap verileri alınamadı');
  }

  Future<List<dynamic>> summary() async {
    final response = await _api.get(ApiConfig.occupancySummary);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Özet veriler alınamadı');
  }
}

/// Admin API
class AdminService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final response = await _api.get(ApiConfig.adminDashboard);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw ApiException('Dashboard verileri alınamadı');
  }

  Future<List<dynamic>> listScanners() async {
    final response = await _api.get(ApiConfig.adminScanners);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    throw ApiException('Tarayıcılar alınamadı');
  }

  Future<Map<String, dynamic>> createScanner(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.adminScanners, data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    final err = jsonDecode(response.body);
    throw ApiException(err['detail'] ?? 'Tarayıcı oluşturulamadı');
  }

  Future<void> deleteScanner(int id) async {
    final response = await _api.delete(ApiConfig.adminScannerDelete(id));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw ApiException('Tarayıcı silinemedi');
    }
  }
}

class ApiException implements Exception {
  final dynamic message;
  ApiException(this.message);

  String _translateError(String errorMsg) {
    final lowerMsg = errorMsg.toLowerCase();
    if (lowerMsg.contains('incorrect username or password') || lowerMsg.contains('invalid email or password')) {
      return 'Kullanıcı adı veya şifre hatalı';
    }
    if (lowerMsg.contains('user already exists') || lowerMsg.contains('email already registered')) {
      return 'Bu e-posta adresi zaten kullanılıyor';
    }
    if (lowerMsg.contains('not a valid email')) {
      return 'Geçerli bir e-posta adresi giriniz';
    }
    if (lowerMsg.contains('inactive user')) {
      return 'Hesabınız aktif değil';
    }
    if (lowerMsg.contains('not authenticated') || lowerMsg.contains('not enough segments')) {
      return 'Oturumunuz süresi doldu veya geçersiz, tekrar giriş yapın';
    }
    return errorMsg;
  }

  @override
  String toString() {
    String parsedMsg = 'Bir hata oluştu';
    
    if (message is String) {
      parsedMsg = message;
    } else if (message is List && message.isNotEmpty) {
      // FastAPI validation error listesi
      final first = message.first;
      if (first is Map && first.containsKey('msg')) {
        parsedMsg = first['msg'].toString();
      } else {
        parsedMsg = message.join(', ');
      }
    } else if (message is Map) {
      if (message.containsKey('detail')) {
        parsedMsg = message['detail'].toString();
      } else if (message.containsKey('message')) {
        parsedMsg = message['message'].toString();
      } else {
        parsedMsg = jsonEncode(message);
      }
    } else {
      try {
        parsedMsg = jsonEncode(message);
      } catch (_) {
        parsedMsg = message.toString();
      }
    }
    
    return _translateError(parsedMsg);
  }
}
