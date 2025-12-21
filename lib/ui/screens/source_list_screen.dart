import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'session_list_screen.dart';
import '../../utils/search_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/source_provider.dart';
import '../../models.dart';

enum SortOption { recent, count, alphabetical }

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  List<Source> _filteredSources = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  final Map<String, int> _usageCount = {};
  final Map<String, DateTime> _lastUsed = {};
  SortOption _currentSort = SortOption.recent;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final sources = sourceProvider.sources;

    final filtered = filterAndSort<Source>(
      items: sources,
      query: _searchController.text,
      accessors: [
        (source) => source.githubRepo?.repo ?? '',
        (source) => source.name,
        (source) => source.githubRepo?.owner ?? '',
      ],
    );

    setState(() {
      _filteredSources = _sortSources(filtered);
    });
  }

  List<Source> _sortSources(List<Source> sources) {
    // We create a copy to avoid sorting the original list in place if that matters,
    // though filterAndSort returns a new list usually.
    final sorted = List<Source>.from(sources);
    sorted.sort((a, b) {
      switch (_currentSort) {
        case SortOption.recent:
          final lastUsedA = _lastUsed[a.name];
          final lastUsedB = _lastUsed[b.name];
          if (lastUsedA == null && lastUsedB == null) {
            // Fallback to count
            final countA = _usageCount[a.name] ?? 0;
            final countB = _usageCount[b.name] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            // Fallback to alphabetical
            return _compareAlphabetical(a, b);
          }
          if (lastUsedA == null) return 1;
          if (lastUsedB == null) return -1;
          final cmp = lastUsedB.compareTo(lastUsedA);
          if (cmp != 0) return cmp;
          break;
        case SortOption.count:
          final countA = _usageCount[a.name] ?? 0;
          final countB = _usageCount[b.name] ?? 0;
          final cmp = countB.compareTo(countA);
          if (cmp != 0) return cmp;
          // Fallback to recent
          final lastUsedA = _lastUsed[a.name];
          final lastUsedB = _lastUsed[b.name];
          if (lastUsedA != null && lastUsedB != null) {
             final timeCmp = lastUsedB.compareTo(lastUsedA);
             if (timeCmp != 0) return timeCmp;
          }
          break;
        case SortOption.alphabetical:
          // Already handled by default fallthrough
          break;
      }
      return _compareAlphabetical(a, b);
    });
    return sorted;
  }

  int _compareAlphabetical(Source a, Source b) {
    final nameA = a.githubRepo?.repo ?? a.name;
    final nameB = b.githubRepo?.repo ?? b.name;
    return nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  Future<void> _fetchData({bool force = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = Provider.of<AuthProvider>(context, listen: false).client;
      final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

      // Listen for source provider updates to update UI progressively
      void updateListener() {
        if (mounted) {
          setState(() {
            _onSearchChanged();
          });
        }
      }
      
      sourceProvider.addListener(updateListener);

      try {
        // Run both requests
        await Future.wait([
          sourceProvider.fetchSources(client, force: force),
          client.listSessions().then((response) {
            _processSessions(response.sessions);
          }),
        ]);

        // Show completion snackbar
        if (mounted && sourceProvider.fetchComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${sourceProvider.sources.length} sources in ${sourceProvider.totalPages} page${sourceProvider.totalPages != 1 ? 's' : ''}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } finally {
        sourceProvider.removeListener(updateListener);
      }

      if (mounted) {
        setState(() {
          _onSearchChanged();
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

  void _processSessions(List<Session> sessions) {
      _usageCount.clear();
      _lastUsed.clear();

      for (final session in sessions) {
        final sourceName = session.sourceContext.source;
        _usageCount[sourceName] = (_usageCount[sourceName] ?? 0) + 1;

        DateTime? sessionTime;
        if (session.updateTime != null) {
          sessionTime = DateTime.tryParse(session.updateTime!);
        }
        if (sessionTime == null && session.createTime != null) {
          sessionTime = DateTime.tryParse(session.createTime!);
        }

        if (sessionTime != null) {
          final existing = _lastUsed[sourceName];
          if (existing == null || sessionTime.isAfter(existing)) {
            _lastUsed[sourceName] = sessionTime;
          }
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          PopupMenuButton<SortOption>(
            initialValue: _currentSort,
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (SortOption item) {
              setState(() {
                _currentSort = item;
                _onSearchChanged();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(
                value: SortOption.recent,
                child: Text('Most Recently Used'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.count,
                child: Text('Usage Count'),
              ),
              const PopupMenuItem<SortOption>(
                value: SortOption.alphabetical,
                child: Text('Alphabetical'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: () => _fetchData(force: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Consumer<SourceProvider>(
              builder: (context, sourceProvider, child) {
                if (sourceProvider.isFetching && sourceProvider.currentPage > 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading page ${sourceProvider.currentPage}...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${sourceProvider.sources.length} sources loaded so far',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            )
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
                          onPressed: () => _fetchData(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search Sources',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Consumer<SourceProvider>(
                        builder: (context, sourceProvider, child) {
                          // The list is actually driven by _filteredSources which is local state,
                          // but updated when sourceProvider changes via _onSearchChanged inside build?
                          // No, _onSearchChanged updates _filteredSources in setState.
                          // But we need to listen to sourceProvider changes if we want real-time updates?
                          // _fetchData calls sourceProvider.fetchSources, which updates the provider.
                          // Then we call setState which calls _onSearchChanged.
                          // So it works for the fetch cycle.
                          // But if another part of the app updates sources, this screen won't know unless we listen.
                          // Consumer is here, but we are using _filteredSources.
                          // We should probably trigger _onSearchChanged when provider updates?
                          // But we can't call setState during build.
                          // It's cleaner to just rebuild the list here if we can, but sorting/filtering is expensive.
                          // For now, reliance on _fetchData is fine as it's the main entry point.
                          // But let's check if we should just use Consumer to trigger rebuilds.

                          // If we use Consumer, we can just rebuild the list.
                          // But sorting logic is in state.
                          return ListView.builder(
                            itemCount: _filteredSources.length,
                            itemBuilder: (context, index) {
                              final source = _filteredSources[index];
                              final count = _usageCount[source.name] ?? 0;
                              final lastUsedDate = _lastUsed[source.name];

                              final repo = source.githubRepo;
                              final isPrivate = repo?.isPrivate ?? false;
                              final defaultBranch = repo?.defaultBranch?.displayName ?? 'N/A';
                              final branchCount = repo?.branches?.length;

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: Icon(isPrivate ? Icons.lock : Icons.public),
                                  title: Text(repo?.repo ?? source.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${repo?.owner ?? "Unknown Owner"} • $defaultBranch${branchCount != null ? " • $branchCount branches" : ""}'),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (count > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$count sessions',
                                                style: Theme.of(context).textTheme.labelSmall,
                                              ),
                                            ),
                                          if (count > 0) const SizedBox(width: 8),
                                          if (lastUsedDate != null)
                                            Text(
                                              'Last used: ${DateFormat.yMMMd().format(lastUsedDate)}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          if (count == 0)
                                             Text(
                                              'Never used',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            SessionListScreen(sourceFilter: source.name),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
    );
  }
}
