import 'package:flutter/material.dart';
import '../../services/jules_client.dart';
import '../../models.dart';

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  final JulesClient _client = JulesClient(apiKey: 'YOUR_API_KEY');
  List<Source> _sources = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sources = await _client.listSources();
      setState(() {
        _sources = sources;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  itemCount: _sources.length,
                  itemBuilder: (context, index) {
                    final source = _sources[index];
                    return ListTile(
                      title: Text(source.githubRepo?.repo ?? source.name),
                      subtitle: Text(source.githubRepo?.owner ?? ''),
                      leading: const Icon(Icons.code),
                    );
                  },
                ),
    );
  }
}
