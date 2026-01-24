import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/github_provider.dart';

class GithubPatDialog extends StatefulWidget {
  const GithubPatDialog({super.key});

  @override
  State<GithubPatDialog> createState() => _GithubPatDialogState();
}

class _GithubPatDialogState extends State<GithubPatDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update GitHub PAT'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your GitHub Personal Access Token may be invalid or expired. Please enter a new one.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'New GitHub PAT',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _savePat,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _savePat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final githubProvider = Provider.of<GithubProvider>(
        context,
        listen: false,
      );
      await githubProvider.setApiKey(_controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub PAT updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update PAT: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
