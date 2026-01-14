import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _tokenKey = 'jules_api_token';
  static const _tokenTypeKey = 'jules_token_type';
  final _storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on PlatformException catch (e) {
      debugPrint('Error saving token: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on PlatformException catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }

  Future<void> saveTokenType(String type) async {
    try {
      await _storage.write(key: _tokenTypeKey, value: type);
    } on PlatformException catch (e) {
      debugPrint('Error saving token type: $e');
    }
  }

  Future<String?> getTokenType() async {
    try {
      return await _storage.read(key: _tokenTypeKey);
    } on PlatformException catch (e) {
      debugPrint('Error reading token type: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _tokenTypeKey);
    } on PlatformException catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }
}
