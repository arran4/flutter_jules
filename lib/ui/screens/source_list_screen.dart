import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'session_list_screen.dart';
import '../../utils/search_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';

enum SortOption { recent, count, alphabetical }

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  List<Source> _filteredSources = [];
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
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final sources = sessionProvider.sources;

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

    final client = Provider.of<AuthProvider>(context, listen: false).client;
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

    await Future.wait([
      sessionProvider.fetchSources(client, force: force),
      sessionProvider.fetchSessions(client, force: force),
    ]);

    if (!mounted) return;

    final sessions = sessionProvider.sessions;

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

    _onSearchChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, child) {
        final isLoading = sessionProvider.isFetchingSources || sessionProvider.isFetching;
        final error = sessionProvider.error;

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
          body: isLoading && _filteredSources.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : error != null && _filteredSources.isEmpty
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
                              error,
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
                        if (isLoading)
                           const LinearProgressIndicator(),
                        Expanded(
                          child: ListView.builder(
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
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
