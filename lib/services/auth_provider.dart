import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';
import 'jules_client.dart';

enum TokenType { apiKey, accessToken }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/cloud-platform'],
  );

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

  Future<void> validateToken(String token, TokenType type) async {
    final client = type == TokenType.apiKey
        ? JulesClient(apiKey: token)
        : JulesClient(accessToken: token);
    try {
      await client.listSessions(pageSize: 1);
    } finally {
      client.close();
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
    await _authService.saveTokenType(
      type == TokenType.apiKey ? 'apiKey' : 'accessToken',
    );
    _token = token;
    _tokenType = type;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User canceled the sign-in
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;

      if (accessToken != null) {
        await setToken(accessToken, TokenType.accessToken);
      } else {
        throw Exception('Failed to obtain access token from Google Sign-In');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.deleteToken();
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // Ignore errors if sign out fails
    }
    _token = null;
    notifyListeners();
  }
}
