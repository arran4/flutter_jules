import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../models.dart';
import 'session_list_screen.dart';

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  List<Source> _sources = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSources();
    });
  }

  Future<void> _fetchSources() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final sources = await client.listSources();
      if (mounted) {
        setState(() {
          _sources = sources;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSources,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 16),
                        Text(
                          'Error Loading Sources',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchSources,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    return ListTile(
                      title: Text(source.githubRepo?.repo ?? source.name),
                      subtitle: Text(source.githubRepo?.owner ?? ''),
                      leading: const Icon(Icons.code),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SessionListScreen(
                              sourceFilter: source.name,
                              sourceDisplayName:
                                  source.githubRepo?.repo ?? source.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
