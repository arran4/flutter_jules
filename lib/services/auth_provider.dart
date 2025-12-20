import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'jules_client.dart';

enum TokenType { apiKey, accessToken }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  TokenType _tokenType = TokenType.accessToken;
  bool _isLoading = true;

  String? get token => _token;
  TokenType get tokenType => _tokenType;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  JulesClient get client {
    if (_tokenType == TokenType.apiKey) {
      return JulesClient(apiKey: _token);
    } else {
      return JulesClient(accessToken: _token);
    }
  }

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    _token = await _authService.getToken();
    final typeStr = await _authService.getTokenType();
    if (typeStr == 'apiKey') {
      _tokenType = TokenType.apiKey;
    } else {
      _tokenType = TokenType.accessToken;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setToken(String token, TokenType type) async {
    await _authService.saveToken(token);
    await _authService.saveTokenType(type == TokenType.apiKey ? 'apiKey' : 'accessToken');
    _token = token;
    _tokenType = type;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.deleteToken();
    _token = null;
    notifyListeners();
  }
}
