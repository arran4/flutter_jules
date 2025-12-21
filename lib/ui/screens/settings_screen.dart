import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/dev_mode_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;
  late TokenType _selectedType;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _tokenController = TextEditingController(text: authProvider.token);
    _selectedType = authProvider.tokenType;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _saveToken() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.setToken(_tokenController.text.trim(), _selectedType);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'API Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TokenType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Token Type',
                border: OutlineInputBorder(),
              ),
              items: TokenType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type == TokenType.apiKey ? 'API Key' : 'Access Token'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'API Token',
                border: OutlineInputBorder(),
                hintText: 'Enter your token',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveToken,
              child: const Text('Update Token'),
            ),
            const Divider(height: 32),
            const Text(
              'Developer Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Dev Mode'),
              subtitle: const Text('Enable advanced debugging features'),
              value: Provider.of<DevModeProvider>(context).isDevMode,
              onChanged: (value) {
                Provider.of<DevModeProvider>(context, listen: false).toggleDevMode(value);
              },
            ),
            SwitchListTile(
              title: const Text('API Logging'),
              subtitle: const Text('Log API requests and responses to console'),
              value: Provider.of<DevModeProvider>(context).enableApiLogging,
              onChanged: (value) {
                Provider.of<DevModeProvider>(context, listen: false).toggleApiLogging(value);
              },
            ),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout / Clear Token'),
            ),
          ],
        ),
      ),
    );
  }
}
