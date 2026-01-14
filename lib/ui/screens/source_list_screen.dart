import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/models/filter_expression_parser.dart';
import 'package:intl/intl.dart';
import 'session_list_screen.dart';
import '../../utils/search_helper.dart';
import '../../utils/time_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';
import '../../services/source_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';
import '../../services/cache_service.dart';
import '../widgets/model_viewer.dart';
import '../widgets/new_session_dialog.dart';
import '../../services/filter_bookmark_provider.dart';
import '../widgets/source_stats_dialog.dart';
import '../widgets/source_tile.dart';

enum SortOption { recent, count, alphabetical }

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  List<CachedItem<Source>> _filteredSources = [];
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
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final sessions = sessionProvider.items.map((i) => i.data).toList();

    _usageCount.clear();
    _lastUsed.clear();

    for (final session in sessions) {
      final sourceName = session.sourceContext?.source ?? '';
      if (sourceName.isEmpty) continue;
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
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final githubProvider = Provider.of<GithubProvider>(context, listen: false);

    // This will trigger both source and session refreshes
    await sourceProvider.fetchSources(
      auth.client,
      authToken: auth.token,
      force: true,
      githubProvider: githubProvider,
      sessionProvider: sessionProvider,
    );

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

  void _showRawData(BuildContext context) {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);

    final sources = sourceProvider.items.map((i) {
      return {
        'name': i.data.name,
        'id': i.data.id,
        'githubRepo': i.data.githubRepo != null
            ? {
                'owner': i.data.githubRepo!.owner,
                'repo': i.data.githubRepo!.repo,
                'branches': i.data.githubRepo!.branches
                    ?.map((b) => b.displayName)
                    .toList(),
                'defaultBranch': i.data.githubRepo!.defaultBranch?.displayName,
                'isPrivate': i.data.githubRepo!.isPrivate,
              }
            : null,
        'metadata': {
          'isNew': i.metadata.isNew,
          'isUpdated': i.metadata.isUpdated,
          'lastRetrieved': i.metadata.lastRetrieved.toIso8601String(),
        },
      };
    }).toList();

    showDialog(
      context: context,
      builder: (context) => ModelViewer(
        data: {'sources': sources, 'count': sources.length},
        title: 'Raw Source Data',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SourceProvider>(
      builder: (context, sourceProvider, child) {
        final sources = sourceProvider.items;
        final isLoading = sourceProvider.isLoading;
        final error = sourceProvider.error;
        final lastFetchTime = sourceProvider.lastFetchTime;

        // If sources updated (e.g. background fetch finished), update our filtered list
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              sourceProvider.items.length != (_filteredSources.length) &&
              _searchController.text.isEmpty) {
            // Trigger re-filter if data changed and we aren't actively searching
          }
        });

        var filtered = filterAndSort<CachedItem<Source>>(
          items: sources,
          query: _searchController.text,
          accessors: [
            (item) => item.data.githubRepo?.repo ?? '',
            (item) => item.data.name,
            (item) => item.data.githubRepo?.owner ?? '',
          ],
        );

        final displaySources = _sortSources(filtered);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Repositories'),
            bottom: isLoading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4.0),
                    child: LinearProgressIndicator(),
                  )
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _refreshData,
              ),
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
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<SortOption>>[
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.pushNamed(context, '/settings');
                  } else if (value == 'raw_data') {
                    _showRawData(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'raw_data',
                    child: Row(
                      children: [
                        Icon(Icons.data_object),
                        SizedBox(width: 8),
                        Text('View Raw Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: (sources.isEmpty && isLoading)
              ? const Center(child: Text("Loading repositories..."))
              : (sources.isEmpty && error != null)
                  ? Center(child: Text('Error: $error'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search Repositories',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                        ),
                        if (lastFetchTime != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Last refreshed: ${DateFormat.Hms().format(lastFetchTime)} (${timeAgo(lastFetchTime)})',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: DateTime.now()
                                                  .difference(lastFetchTime)
                                                  .inMinutes >
                                              30
                                          ? Colors.orange
                                          : null,
                                    ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refreshData,
                            child: displaySources.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                                0.7,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Text(
                                              sources.isEmpty
                                                  ? 'No repositories found.'
                                                  : 'No matches found.',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(), // Ensure refresh works even if few items
                                    controller: _scrollController,
                                    itemCount: displaySources.length,
                                    itemBuilder: (context, index) {
                                      final item = displaySources[index];
                                      final source = item.data;
                                      final count =
                                          _usageCount[source.name] ?? 0;
                                      final lastUsedDate =
                                          _lastUsed[source.name];

                                      return SourceTile(
                                        item: item,
                                        usageCount: count,
                                        lastUsedDate: lastUsedDate,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
