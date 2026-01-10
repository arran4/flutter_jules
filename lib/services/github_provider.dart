import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class GithubProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _githubApiKey = 'github_api_key';

  String? _apiKey;
  bool _isLoading = true;

  String? get apiKey => _apiKey;
  bool get isLoading => _isLoading;

  GithubProvider() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    _apiKey = await _secureStorage.read(key: _githubApiKey);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _githubApiKey, value: apiKey);
    _apiKey = apiKey;
    notifyListeners();
  }

  Future<String?> getPrStatus(String owner, String repo, String prNumber) async {
    if (_apiKey == null) {
      return null;
    }

    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/pulls/$prNumber');
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'token $_apiKey',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['merged'] == true) {
        return 'Merged';
      } else if (data['state'] == 'closed') {
        return 'Closed';
      } else {
        return 'Open';
      }
    } else {
      return null;
    }
  }
}
