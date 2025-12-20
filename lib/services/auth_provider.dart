import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'jules_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  bool _isLoading = true;

  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  JulesClient get client => JulesClient(oauthToken: _token);

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _authService.getToken();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    await _authService.saveToken(token);
    _token = token;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.deleteToken();
    _token = null;
    notifyListeners();
  }
}
