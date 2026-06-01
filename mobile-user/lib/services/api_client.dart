import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_config.dart';
import '../core/constants.dart';

/// HTTP client for the Crowdly backend.
///
/// Pulls its base URL from [ApiConfig] (runtime-mutable). Stores JWT tokens in
/// secure storage and auto-refreshes on 401, mirroring the web client.
class ApiClient {
  ApiClient({ApiConfig? config}) : _config = config ?? _fallbackConfig;

  static final ApiConfig _fallbackConfig = ApiConfig();

  /// Wire the singleton-style fallback so existing call sites that do
  /// `ApiClient()` keep working after `ApiConfig.load()` runs in main().
  static void bindDefaultConfig(ApiConfig config) {
    _instance._config = config;
  }

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() : _config = _fallbackConfig;

  ApiConfig _config;
  final _storage = const FlutterSecureStorage();
  final _httpClient = http.Client();

  String get _baseUrl => _config.baseUrl;

  // ─── Token helpers ────────────────────────────────
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

  Future<Map<String, String>> _headers({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) headers['Content-Type'] = 'application/json';
    final token = await getAccessToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // ─── 401 → refresh & retry ────────────────────────
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
          Uri.parse('$_baseUrl${ApiPaths.authRefresh}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );

        if (refreshResponse.statusCode == 200) {
          final data = jsonDecode(refreshResponse.body);
          await setTokens(data['access_token'], null);
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

  // ─── HTTP verbs ───────────────────────────────────
  Future<http.Response> get(String endpoint, {bool intercept401 = true}) =>
      _handleResponse(() async {
        final headers = await _headers(isJson: false);
        return _httpClient.get(Uri.parse('$_baseUrl$endpoint'), headers: headers);
      }, intercept401: intercept401);

  Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool intercept401 = true,
  }) =>
      _handleResponse(() async {
        final headers = await _headers();
        return _httpClient.post(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        );
      }, intercept401: intercept401);

  Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool intercept401 = true,
  }) =>
      _handleResponse(() async {
        final headers = await _headers();
        return _httpClient.put(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        );
      }, intercept401: intercept401);

  Future<http.Response> patch(String endpoint, {bool intercept401 = true}) =>
      _handleResponse(() async {
        final headers = await _headers();
        return _httpClient.patch(Uri.parse('$_baseUrl$endpoint'), headers: headers);
      }, intercept401: intercept401);

  Future<http.Response> delete(String endpoint, {bool intercept401 = true}) =>
      _handleResponse(() async {
        final headers = await _headers();
        return _httpClient.delete(Uri.parse('$_baseUrl$endpoint'), headers: headers);
      }, intercept401: intercept401);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

@visibleForTesting
ApiClient debugApiClient() => ApiClient();
