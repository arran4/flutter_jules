import 'dart:async';
import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/shortcut_registry.dart' as custom_shortcuts;
import '../../utils/time_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';
import '../../services/source_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';
import '../../services/cache_service.dart';
import '../widgets/advanced_search_bar.dart';
import '../widgets/model_viewer.dart';
import '../../services/message_queue_provider.dart';
import '../widgets/source_tile.dart';
import '../../services/settings_provider.dart';
import '../../services/timer_service.dart';
import '../widgets/group_management_dialog.dart';

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<AdvancedSearchBarState> _searchBarKey = GlobalKey();
  StreamSubscription<AppShortcutAction>? _actionSubscription;

  // Filter and sort state
  FilterElement? _filterTree;
  String _searchText = '';
  List<SortOption> _activeSorts = [
    const SortOption(SortField.updated, SortDirection.descending),
    const SortOption(SortField.count, SortDirection.descending),
    const SortOption(SortField.name, SortDirection.ascending),
  ];
  List<FilterToken> _availableSuggestions = [];

  final Map<String, int> _usageCount = {};
  final Map<String, DateTime> _lastUsed = {};
  Timer? _lastRefreshedTimer;

  @override
  void initState() {
    super.initState();
    _lastRefreshedTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shortcutRegistry = Provider.of<custom_shortcuts.ShortcutRegistry>(
        context,
        listen: false,
      );
      _actionSubscription = shortcutRegistry.onAction.listen((action) {
        if (!mounted) return;
        if (action == AppShortcutAction.focusSearch) {
          _searchBarKey.currentState?.requestFocus();
        }
      });
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _actionSubscription?.cancel();
    _lastRefreshedTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      // Just trigger a rebuild, the filtering logic is in the build method
    });
  }

  List<CachedItem<Source>> _sortSources(List<CachedItem<Source>> sources) {
    final sorted = List<CachedItem<Source>>.from(sources);
    sorted.sort((a, b) {
      for (final sort in _activeSorts) {
        final cmp = _compareBySortOption(sort, a, b);
        if (cmp != 0) {
          return sort.direction == SortDirection.ascending ? cmp : -cmp;
        }
      }
      return _compareAlphabetical(a, b);
    });
    return sorted;
  }

  int _compareBySortOption(
    SortOption sort,
    CachedItem<Source> a,
    CachedItem<Source> b,
  ) {
    return _compareBySortField(sort.field, a, b);
  }

  int _compareBySortField(
    SortField field,
    CachedItem<Source> a,
    CachedItem<Source> b,
  ) {
    switch (field) {
      case SortField.name:
        return _compareAlphabetical(a, b);
      case SortField.updated:
        return _compareByLastUsed(a, b);
      case SortField.count:
        return _compareByUsageCount(a, b);
      default:
        return 0;
    }
  }

  int _compareByLastUsed(CachedItem<Source> a, CachedItem<Source> b) {
    final lastUsedA = _lastUsed[a.data.name];
    final lastUsedB = _lastUsed[b.data.name];
    if (lastUsedA != null && lastUsedB != null) {
      return lastUsedA.compareTo(lastUsedB);
    }
    if (lastUsedA != null) {
      return 1;
    }
    if (lastUsedB != null) {
      return -1;
    }
    return 0;
  }

  int _compareByUsageCount(CachedItem<Source> a, CachedItem<Source> b) {
    final countA = _usageCount[a.data.name] ?? 0;
    final countB = _usageCount[b.data.name] ?? 0;
    return countA.compareTo(countB);
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

    if (sourceProvider.items.isEmpty && !sourceProvider.isLoading) {
      await sourceProvider.fetchSources(auth.client, authToken: auth.token);
    }

    _updateSuggestions(sourceProvider.items.map((i) => i.data).toList());
    _processSessions();
    _onSearchChanged();
    setState(() {}); // Trigger a rebuild to apply the initial sort
  }

  void _updateSuggestions(List<Source> sources) {
    final Set<FilterToken> suggestions = {};
    final Set<String> languages = {};

    for (final source in sources) {
      if (source.githubRepo?.primaryLanguage != null &&
          source.githubRepo!.primaryLanguage!.isNotEmpty) {
        languages.add(source.githubRepo!.primaryLanguage!);
      }
    }

    suggestions.addAll([
      const FilterToken(
        id: 'flag:is:private',
        type: FilterType.flag,
        label: 'Private',
        value: 'is:private',
      ),
      const FilterToken(
        id: 'flag:is:fork',
        type: FilterType.flag,
        label: 'Fork',
        value: 'is:fork',
      ),
      const FilterToken(
        id: 'flag:is:archived',
        type: FilterType.flag,
        label: 'Archived',
        value: 'is:archived',
      ),
    ]);

    for (final lang in languages) {
      suggestions.add(
        FilterToken(
          id: 'flag:lang:$lang',
          type: FilterType.flag,
          label: 'Lang: $lang',
          value: 'lang:${lang.toLowerCase()}',
        ),
      );
    }

    setState(() {
      _availableSuggestions = suggestions.toList()
        ..sort((a, b) => a.label.compareTo(b.label));
    });
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
    final githubProvider = Provider.of<GithubProvider>(context, listen: false);

    // This will trigger source refreshes
    await sourceProvider.fetchSources(
      auth.client,
      authToken: auth.token,
      force: true,
      githubProvider: githubProvider,
    );

    _processSessions();
    setState(() {});

    _showRefreshSnackBar(sourceProvider.items.length);
  }

  void _showRefreshSnackBar(int sourceCount) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Refreshed $sourceCount sources'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  FilterContext _buildFilterContext(
    Source source,
    CacheMetadata metadata,
    BuildContext context,
  ) {
    final labels = <String>{};
    if (source.githubRepo?.isPrivate ?? false) labels.add('is:private');
    if (source.githubRepo?.isFork ?? false) labels.add('is:fork');
    if (source.isArchived) labels.add('is:archived');
    if (source.githubRepo?.primaryLanguage != null) {
      labels.add('lang:${source.githubRepo!.primaryLanguage!.toLowerCase()}');
    }

    final synthMetadata = CacheMetadata(
      firstSeen: metadata.firstSeen,
      lastRetrieved: metadata.lastRetrieved,
      lastOpened: metadata.lastOpened,
      lastUpdated: metadata.lastUpdated,
      labels: labels.toList(),
    );

    final synthSession = Session(
      id: source.id,
      name: source.name,
      title: source.githubRepo?.repo ?? source.name,
      prompt: source.githubRepo?.description ?? '',
      sourceContext: SourceContext(source: source.name),
    );

    return FilterContext(
      session: synthSession,
      metadata: synthMetadata,
      queueProvider: Provider.of<MessageQueueProvider>(context, listen: false),
    );
  }

  bool _sourceMatchesFilters(CachedItem<Source> item, BuildContext context) {
    final source = item.data;
    final metadata = item.metadata;

    if (_searchText.isNotEmpty) {
      final query = _searchText.toLowerCase();
      if (!(source.name.toLowerCase().contains(query) ||
          (source.githubRepo?.repo.toLowerCase().contains(query) ?? false) ||
          (source.githubRepo?.owner.toLowerCase().contains(query) ?? false) ||
          (source.githubRepo?.description?.toLowerCase().contains(query) ??
              false))) {
        return false;
      }
    }

    if (_filterTree == null) return true;

    final filterContext = _buildFilterContext(source, metadata, context);
    return _filterTree!.evaluate(filterContext).isIn;
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
    // Listen to TimerService to trigger periodic rebuilds for relative time updates
    Provider.of<TimerService>(context);
    return Consumer2<SourceProvider, SettingsProvider>(
      builder: (context, sourceProvider, settingsProvider, child) {
        var sources = sourceProvider.items;
        if (settingsProvider.hideArchivedAndReadOnly) {
          sources = sources
              .where((s) => !s.data.isArchived && !s.data.isReadOnly)
              .toList();
        }
        final isLoading = sourceProvider.isLoading;
        final error = sourceProvider.error;
        final lastFetchTime = sourceProvider.lastFetchTime;

        final filteredSources = sources
            .where((item) => _sourceMatchesFilters(item, context))
            .toList();

        final displaySources = _sortSources(filteredSources);

        return Scaffold(
          appBar: _buildAppBar(isLoading),
          body: _buildBody(
            sources: sources,
            isLoading: isLoading,
            error: error,
            displaySources: displaySources,
            lastFetchTime: lastFetchTime,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLoading) {
    return AppBar(
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
        IconButton(
          icon: const Icon(Icons.groups),
          tooltip: 'Manage Groups',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const GroupManagementDialog(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.pushNamed(context, '/settings');
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'raw_data') {
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
          ],
        ),
      ],
    );
  }

  Widget _buildBody({
    required List<CachedItem<Source>> sources,
    required bool isLoading,
    required String? error,
    required List<CachedItem<Source>> displaySources,
    required DateTime? lastFetchTime,
  }) {
    if (sources.isEmpty && isLoading) {
      return const Center(child: Text("Loading repositories..."));
    }
    if (sources.isEmpty && error != null) {
      return Center(child: Text('Error: $error'));
    }

    return Column(
      children: [
        _buildFilterBar(),
        _buildLastRefreshed(lastFetchTime),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: _buildSourcesListBody(sources, displaySources),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return AdvancedSearchBar(
      key: _searchBarKey,
      filterTree: _filterTree,
      onFilterTreeChanged: (tree) {
        setState(() {
          _filterTree = tree;
        });
      },
      searchText: _searchText,
      onSearchChanged: (text) {
        setState(() {
          _searchText = text;
        });
      },
      availableSuggestions: _availableSuggestions,
      activeSorts: _activeSorts,
      onSortsChanged: (sorts) {
        setState(() {
          _activeSorts = sorts;
        });
      },
    );
  }

  Widget _buildLastRefreshed(DateTime? lastFetchTime) {
    if (lastFetchTime == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Last refreshed: ${DateFormat.Hms().format(lastFetchTime)} (${timeAgo(lastFetchTime)})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: DateTime.now().difference(lastFetchTime).inMinutes > 30
                ? Colors.orange
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSourcesListBody(
    List<CachedItem<Source>> sources,
    List<CachedItem<Source>> displaySources,
  ) {
    if (displaySources.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
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
      );
    }
    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensure refresh works even if few items
      controller: _scrollController,
      itemCount: displaySources.length,
      itemBuilder: (context, index) {
        final item = displaySources[index];
        final source = item.data;
        final count = _usageCount[source.name] ?? 0;
        final lastUsedDate = _lastUsed[source.name];

        return SourceTile(
          item: item,
          usageCount: count,
          lastUsedDate: lastUsedDate,
        );
      },
    );
  }
}
