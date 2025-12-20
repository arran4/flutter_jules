import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/data_provider.dart';
import '../../models.dart';

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataProvider>(context, listen: false).fetchSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final sources = provider.sources;
        final isLoading = provider.isSourcesLoading;
        final error = provider.sourcesError;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sources'),
            actions: [
               IconButton(
                icon: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: () => provider.fetchSources(force: true),
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Stack(
            children: [
              if (sources.isEmpty && isLoading)
                const Center(child: CircularProgressIndicator())
              else if (sources.isEmpty && error != null)
                Center(
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
                          error,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.fetchSources(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return ListTile(
                      title: Text(source.githubRepo?.repo ?? source.name),
                      subtitle: Text(source.githubRepo?.owner ?? ''),
                      leading: const Icon(Icons.code),
                    );
                  },
                ),
               if (sources.isNotEmpty && isLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        );
      },
    );
  }
}
