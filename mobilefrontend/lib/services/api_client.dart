import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  final _httpClient = http.Client();

  // Token helpers
  Future<String?> getAccessToken() => _storage.read(key: 'access_token');
  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  Future<void> setTokens(String access, String? refresh) async {
    await _storage.write(key: 'access_token', value: access);
    if (refresh != null) {
      await _storage.write(key: 'refresh_token', value: refresh);
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  // Headers with JWT
  Future<Map<String, String>> _headers({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) headers['Content-Type'] = 'application/json';
    final token = await getAccessToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // Auto-refresh token on 401
  Future<http.Response> _handleResponse(
    Future<http.Response> Function() request, {
    bool intercept401 = true,
  }) async {
    var response = await request();

    if (intercept401 && response.statusCode == 401) {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        await clearTokens();
        throw AuthException('Oturum süresi doldu');
      }

      try {
        final refreshResponse = await _httpClient.post(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.authRefresh}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );

        if (refreshResponse.statusCode == 200) {
          final data = jsonDecode(refreshResponse.body);
          await setTokens(data['access_token'], null);
          // Retry original request
          response = await request();
        } else {
          await clearTokens();
          throw AuthException('Oturum süresi doldu');
        }
      } catch (e) {
        if (e is AuthException) rethrow;
        await clearTokens();
        throw AuthException('Oturum süresi doldu');
      }
    }

    return response;
  }

  // HTTP methods
  Future<http.Response> get(String endpoint, {bool intercept401 = true}) async {
    return _handleResponse(() async {
      final headers = await _headers(isJson: false);
      return _httpClient.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    }, intercept401: intercept401);
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool intercept401 = true}) async {
    return _handleResponse(() async {
      final headers = await _headers();
      return _httpClient.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    }, intercept401: intercept401);
  }

  Future<http.Response> put(String endpoint, Map<String, dynamic> body, {bool intercept401 = true}) async {
    return _handleResponse(() async {
      final headers = await _headers();
      return _httpClient.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    }, intercept401: intercept401);
  }

  Future<http.Response> patch(String endpoint, {bool intercept401 = true}) async {
    return _handleResponse(() async {
      final headers = await _headers();
      return _httpClient.patch(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    }, intercept401: intercept401);
  }

  Future<http.Response> delete(String endpoint, {bool intercept401 = true}) async {
    return _handleResponse(() async {
      final headers = await _headers();
      return _httpClient.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    }, intercept401: intercept401);
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
