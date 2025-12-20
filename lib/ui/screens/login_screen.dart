import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  TokenType _selectedType = TokenType.accessToken;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _saveToken() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setToken(_tokenController.text.trim(), _selectedType);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Jules API'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Please provide your API Token to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<TokenType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Token Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: TokenType.accessToken,
                    child: Text('OAuth Access Token'),
                  ),
                  DropdownMenuItem(
                    value: TokenType.apiKey,
                    child: Text('API Key'),
                  ),
                ],
                onChanged: (TokenType? value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tokenController,
                decoration: InputDecoration(
                  labelText: _selectedType == TokenType.apiKey ? 'API Key' : 'Access Token',
                  border: const OutlineInputBorder(),
                  hintText: _selectedType == TokenType.apiKey
                      ? 'Enter your API Key'
                      : 'Enter your Bearer token',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a token';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveToken,
                child: const Text('Save and Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
