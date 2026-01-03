import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'session_list_screen.dart';
import '../../utils/search_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/source_provider.dart';
import '../../services/session_provider.dart'; // Needed for stats
import '../../models.dart';
import '../../models/cache_metadata.dart'; // For CachedItem
import '../../services/cache_service.dart'; // For CachedItem type if needed

enum SortOption { recent, count, alphabetical }

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  List<CachedItem<Source>> _filteredSources = [];
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, int> _usageCount = {};
  final Map<String, DateTime> _lastUsed = {};
  SortOption _currentSort = SortOption.recent;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final sources = sourceProvider.items;

    final filtered = filterAndSort<CachedItem<Source>>(
      items: sources,
      query: _searchController.text,
      accessors: [
        (item) => item.data.githubRepo?.repo ?? '',
        (item) => item.data.name,
        (item) => item.data.githubRepo?.owner ?? '',
      ],
    );

    setState(() {
      _filteredSources = _sortSources(filtered);
    });
  }

  List<CachedItem<Source>> _sortSources(List<CachedItem<Source>> sources) {
    final sorted = List<CachedItem<Source>>.from(sources);
    sorted.sort((a, b) {
      final nameA = a.data.name;
      final nameB = b.data.name;
      
      switch (_currentSort) {
        case SortOption.recent:
          final lastUsedA = _lastUsed[nameA];
          final lastUsedB = _lastUsed[nameB];
          if (lastUsedA == null && lastUsedB == null) {
            final countA = _usageCount[nameA] ?? 0;
            final countB = _usageCount[nameB] ?? 0;
            if (countA != countB) return countB.compareTo(countA);
            return _compareAlphabetical(a, b);
          }
          if (lastUsedA == null) return 1;
          if (lastUsedB == null) return -1;
          final cmp = lastUsedB.compareTo(lastUsedA);
          if (cmp != 0) return cmp;
          break;
        case SortOption.count:
          final countA = _usageCount[nameA] ?? 0;
          final countB = _usageCount[nameB] ?? 0;
          final cmp = countB.compareTo(countA);
          if (cmp != 0) return cmp;
          
          final lastUsedA = _lastUsed[nameA];
          final lastUsedB = _lastUsed[nameB];
          if (lastUsedA != null && lastUsedB != null) {
            final timeCmp = lastUsedB.compareTo(lastUsedA);
            if (timeCmp != 0) return timeCmp;
          }
          break;
        case SortOption.alphabetical:
          break;
      }
      return _compareAlphabetical(a, b);
    });
    return sorted;
  }

  int _compareAlphabetical(CachedItem<Source> a, CachedItem<Source> b) {
    final nameA = a.data.githubRepo?.repo ?? a.data.name;
    final nameB = b.data.githubRepo?.repo ?? b.data.name;
    return nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    // Fetch sources if empty, but usually SessionListScreen triggered it. 
    // Just ensure we have data or are loading.
    if (sourceProvider.items.isEmpty && !sourceProvider.isLoading) {
        await sourceProvider.fetchSources(auth.client, authToken: auth.token);
    }
    
    // Load usage stats from SessionProvider
    _processSessions();
    _onSearchChanged(); // Update filter
  }

  void _processSessions() {
    // We can get sessions from SessionProvider
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    final sessions = sessionProvider.items.map((i) => i.data).toList();

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

  Future<void> _refreshData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);

    await Future.wait([
      sourceProvider.fetchSources(auth.client, authToken: auth.token),
      sessionProvider.fetchSessions(auth.client, authToken: auth.token, force: true) // Also refresh stats
    ]);
    
    _processSessions();
    _onSearchChanged();
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshed ${sourceProvider.items.length} sources'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources (Raw Data)'),
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
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<SourceProvider>(
        builder: (context, sourceProvider, child) {
            
          // If sources updated (e.g. background fetch finished), update our filtered list
          // This might cause loop if we setState in build, but only if items changed
          WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted && sourceProvider.items.length != (_filteredSources.length) && _searchController.text.isEmpty) {
                 // Very rough check, better to compare list instances or timestamp
                 // Just trigger re-filter if idle?
                 // Or rely on Provider listener?
                 // The Consumer rebuilds, but _filteredSources is local state relying on _onSearchChanged.
                 // We should re-run filter when provider notifies.
                 // _onSearchChanged uses provider.items.
             }
          });
          
          // Re-run filter on build? Efficient enough?
          // Instead of local state `_filteredSources`, we could calculate it in build.
          // Let's do that for simplicity and correctness with Consumer.
          
          final sources = sourceProvider.items;
          var filtered = filterAndSort<CachedItem<Source>>(
              items: sources,
              query: _searchController.text,
              accessors: [
                (item) => item.data.githubRepo?.repo ?? '',
                (item) => item.data.name,
                (item) => item.data.githubRepo?.owner ?? '',
              ],
            );
          
          // Sort
          final displaySources = _sortSources(filtered);

          if (sourceProvider.isLoading && sources.isEmpty) {
             return const Center(child: CircularProgressIndicator());
          }
          
          if (sourceProvider.error != null && sources.isEmpty) {
              return Center(child: Text('Error: ${sourceProvider.error}'));
          }

          return Column(
            children: [
               if (sourceProvider.isLoading)
                const LinearProgressIndicator(),
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
                child: displaySources.isEmpty
                    ? Center(child: Text( sources.isEmpty ? 'No sources loaded.' : 'No matches.'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: displaySources.length,
                        itemBuilder: (context, index) {
                          final item = displaySources[index];
                          final source = item.data;
                          
                          final count = _usageCount[source.name] ?? 0;
                          final lastUsedDate = _lastUsed[source.name];

                          final repo = source.githubRepo;
                          final isPrivate = repo?.isPrivate ?? false;
                          final defaultBranch =
                              repo?.defaultBranch?.displayName ?? 'N/A';
                          final branchCount = repo?.branches?.length;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading:
                                  Icon(isPrivate ? Icons.lock : Icons.public),
                              title: Text(repo?.repo ?? source.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      '${repo?.owner ?? "Unknown Owner"} • $defaultBranch${branchCount != null ? " • $branchCount branches" : ""}'),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (count > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$count sessions',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                      if (count > 0) const SizedBox(width: 8),
                                      if (lastUsedDate != null)
                                        Text(
                                          'Last used: ${DateFormat.yMMMd().format(lastUsedDate)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      if (item.metadata.isNew)
                                         Padding(
                                           padding: const EdgeInsets.only(left: 8.0),
                                           child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              color: Colors.green,
                                              child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10))),
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
                                    builder: (context) => SessionListScreen(
                                        sourceFilter: source.name),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
