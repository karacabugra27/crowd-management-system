import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';

/// AuthProvider — web frontend AuthContext.jsx ile aynı mantık
class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();
  final _usersService = UsersService();
  final _apiClient = ApiClient();

  Map<String, dynamic>? _user;
  bool _loading = true;

  Map<String, dynamic>? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?['role'] == 'admin';
  String? get email => _user?['email'];

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final token = await _apiClient.getAccessToken();
    if (token != null) {
      await fetchUser();
    } else {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUser() async {
    try {
      _user = await _usersService.getMe();
    } catch (e) {
      _user = null;
      await _apiClient.clearTokens();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _authService.login(email, password);
    await fetchUser();
  }

  Future<void> register(String email, String password) async {
    await _authService.register(email, password);
    await fetchUser();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }
}
