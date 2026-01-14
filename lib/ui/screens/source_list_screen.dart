import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_jules/models/filter_expression_parser.dart';
import 'package:intl/intl.dart';
import 'session_list_screen.dart';
import '../../utils/time_helper.dart';
import '../../services/auth_provider.dart';
import '../../services/github_provider.dart';
import '../../services/source_provider.dart';
import '../../services/session_provider.dart';
import '../../models.dart';
import '../../services/cache_service.dart';
import '../widgets/advanced_search_bar.dart';
import '../widgets/model_viewer.dart';
import '../widgets/new_session_dialog.dart';
import '../../services/filter_bookmark_provider.dart';
import '../../services/message_queue_provider.dart';
import '../widgets/source_stats_dialog.dart';

class SourceListScreen extends StatefulWidget {
  const SourceListScreen({super.key});

  @override
  State<SourceListScreen> createState() => _SourceListScreenState();
}

class _SourceListScreenState extends State<SourceListScreen> {
  final ScrollController _scrollController = ScrollController();

  // Filter and sort state
  FilterElement? _filterTree;
  String _searchText = '';
  List<SortOption> _activeSorts = [
    const SortOption(SortField.updated, SortDirection.descending),
    const SortOption(SortField.count, SortDirection.descending),
    const SortOption(SortField.name, SortDirection.ascending)
  ];
  List<FilterToken> _availableSuggestions = [];

  final Map<String, int> _usageCount = {};
  final Map<String, DateTime> _lastUsed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  List<CachedItem<Source>> _sortSources(List<CachedItem<Source>> sources) {
    final sorted = List<CachedItem<Source>>.from(sources);
    sorted.sort((a, b) {
      for (final sort in _activeSorts) {
        int cmp = 0;
        switch (sort.field) {
          case SortField.name:
            cmp = _compareAlphabetical(a, b);
            break;
          case SortField.updated: // For 'recent'
            final lastUsedA = _lastUsed[a.data.name];
            final lastUsedB = _lastUsed[b.data.name];
            if (lastUsedA != null && lastUsedB != null) {
              cmp = lastUsedA.compareTo(lastUsedB);
            } else if (lastUsedA != null) {
              cmp = 1;
            } else if (lastUsedB != null) {
              cmp = -1;
            }
            break;
          case SortField.count:
            final countA = _usageCount[a.data.name] ?? 0;
            final countB = _usageCount[b.data.name] ?? 0;
            cmp = countA.compareTo(countB);
            break;
          default:
            break;
        }
        if (cmp != 0) {
          return sort.direction == SortDirection.ascending ? cmp : -cmp;
        }
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

    if (sourceProvider.items.isEmpty && !sourceProvider.isLoading) {
      await sourceProvider.fetchSources(auth.client, authToken: auth.token);
    }

    _updateSuggestions(sourceProvider.items.map((i) => i.data).toList());
    _processSessions();
    _onSearchChanged();
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
          value: 'is:private'),
      const FilterToken(
          id: 'flag:is:fork',
          type: FilterType.flag,
          label: 'Fork',
          value: 'is:fork'),
      const FilterToken(
          id: 'flag:is:archived',
          type: FilterType.flag,
          label: 'Archived',
          value: 'is:archived'),
    ]);

    for (final lang in languages) {
      suggestions.add(FilterToken(
          id: 'flag:lang:$lang',
          type: FilterType.flag,
          label: 'Lang: $lang',
          value: 'lang:${lang.toLowerCase()}'));
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

        final filteredSources = sources.where((item) {
          final source = item.data;
          final metadata = item.metadata;

          if (_searchText.isNotEmpty) {
            final query = _searchText.toLowerCase();
            if (!(source.name.toLowerCase().contains(query) ||
                (source.githubRepo?.repo.toLowerCase().contains(query) ??
                    false) ||
                (source.githubRepo?.owner.toLowerCase().contains(query) ??
                    false) ||
                (source.githubRepo?.description?.toLowerCase().contains(query) ??
                    false))) {
              return false;
            }
          }

          if (_filterTree == null) return true;

          final labels = <String>{};
          if (source.githubRepo?.isPrivate ?? false) labels.add('is:private');
          if (source.githubRepo?.isFork ?? false) labels.add('is:fork');
          if (source.githubRepo?.isArchived ?? false) labels.add('is:archived');
          if (source.githubRepo?.primaryLanguage != null) {
            labels.add(
                'lang:${source.githubRepo!.primaryLanguage!.toLowerCase()}');
          }

          final synthMetadata = CacheMetadata(
            firstSeen: metadata.firstSeen,
            lastRetrieved: metadata.lastRetrieved,
            isNew: metadata.isNew,
            isUpdated: metadata.isUpdated,
            labels: labels,
          );

          final synthSession = Session(
            id: source.id,
            name: source.name,
            title: source.githubRepo?.repo ?? source.name,
            prompt: source.githubRepo?.description ?? '',
            sourceContext: SourceContext(source: source.name),
          );

          final context = FilterContext(
            session: synthSession,
            metadata: synthMetadata,
            queueProvider:
                Provider.of<MessageQueueProvider>(context, listen: false),
          );

          return _filterTree!.evaluate(context).isIn;
        }).toList();

        final displaySources = _sortSources(filteredSources);

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
                        AdvancedSearchBar(
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

                                      final repo = source.githubRepo;
                                      final isPrivate =
                                          repo?.isPrivate ?? false;
                                      final defaultBranch =
                                          repo?.defaultBranch?.displayName ??
                                              'N/A';
                                      final branchCount =
                                          repo?.branches?.length;

                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: ListTile(
                                          leading: Icon(
                                            isPrivate
                                                ? Icons.lock
                                                : Icons.public,
                                          ),
                                          title: Row(
                                            children: [
                                              if (isPrivate)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 6.0,
                                                  ),
                                                  child: Icon(
                                                    Icons.lock,
                                                    size: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  repo?.repo ?? source.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (repo?.description != null &&
                                                  repo!.description!.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 4.0,
                                                  ),
                                                  child: Text(
                                                    repo.description!,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ),
                                              Text(
                                                '${repo?.owner ?? "Unknown Owner"} • $defaultBranch${branchCount != null ? " • $branchCount branches" : ""}',
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (repo?.primaryLanguage !=
                                                      null)
                                                    _buildInfoPill(
                                                      context,
                                                      repo!.primaryLanguage!,
                                                      Icons.code,
                                                    ),
                                                  if (repo?.openIssuesCount !=
                                                          null &&
                                                      repo!.openIssuesCount! >
                                                          0)
                                                    _buildInfoPill(
                                                      context,
                                                      '${repo.openIssuesCount} open issues',
                                                      Icons.bug_report,
                                                    ),
                                                  if (repo?.isFork ?? false)
                                                    _buildInfoPill(
                                                      context,
                                                      'Fork',
                                                      Icons.call_split,
                                                    ),
                                                  if (item.metadata.isNew)
                                                    _buildStatusPill(
                                                      context,
                                                      'NEW',
                                                      Colors.green,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  if (count > 0)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          4,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        '$count sessions',
                                                        style: Theme.of(
                                                          context,
                                                        ).textTheme.labelSmall,
                                                      ),
                                                    ),
                                                  if (count > 0)
                                                    const SizedBox(width: 8),
                                                  if (lastUsedDate != null)
                                                    Text(
                                                      'Last used: ${DateFormat.yMMMd().format(lastUsedDate)}',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.bodySmall,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.refresh),
                                                tooltip: 'Refresh source',
                                                onPressed: () async {
                                                  final sourceProvider =
                                                      Provider.of<
                                                              SourceProvider>(
                                                          context,
                                                          listen: false);
                                                  final githubProvider =
                                                      Provider.of<
                                                              GithubProvider>(
                                                          context,
                                                          listen: false);
                                                  final auth =
                                                      Provider.of<AuthProvider>(
                                                          context,
                                                          listen: false);
                                                  try {
                                                    await sourceProvider
                                                        .refreshSource(
                                                      source,
                                                      authToken: auth.token,
                                                      githubProvider:
                                                          githubProvider,
                                                    );
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Refreshed ${source.githubRepo?.repo ?? source.name}'),
                                                          duration:
                                                              const Duration(
                                                                  seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              'Failed to refresh ${source.githubRepo?.repo ?? source.name}: $e'),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add),
                                                tooltip: 'New session',
                                                onPressed: () =>
                                                    _handleNewSession(
                                                        source.name),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.filter_list),
                                                tooltip:
                                                    'Filter by this source',
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          SessionListScreen(
                                                        sourceFilter:
                                                            source.name,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              PopupMenuButton<String>(
                                                onSelected: (value) async {
                                                  if (value ==
                                                      'refresh_sessions') {
                                                    final sessionProvider =
                                                        Provider.of<
                                                                SessionProvider>(
                                                            context,
                                                            listen: false);
                                                    final auth = Provider.of<
                                                            AuthProvider>(
                                                        context,
                                                        listen: false);
                                                    try {
                                                      await sessionProvider
                                                          .refreshSessionsForSource(
                                                        auth.client,
                                                        source.name,
                                                        authToken: auth.token!,
                                                      );
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                                'Refreshed sessions for ${source.githubRepo?.repo ?? source.name}'),
                                                            duration:
                                                                const Duration(
                                                                    seconds: 2),
                                                          ),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                                'Failed to refresh sessions for ${source.githubRepo?.repo ?? source.name}: $e'),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  } else if (value == 'stats') {
                                                    _showStatsDialog(source);
                                                  } else if (value.startsWith(
                                                      'bookmark_')) {
                                                    final bookmarkId =
                                                        value.substring(
                                                            'bookmark_'.length);
                                                    _handleBookmark(bookmarkId,
                                                        source.name);
                                                  }
                                                },
                                                itemBuilder: (context) {
                                                  final bookmarkProvider = Provider
                                                      .of<FilterBookmarkProvider>(
                                                          context,
                                                          listen: false);
                                                  final bookmarks =
                                                      bookmarkProvider
                                                          .bookmarks;

                                                  return [
                                                    const PopupMenuItem(
                                                      value: 'refresh_sessions',
                                                      child: Text(
                                                          'Refresh Sessions'),
                                                    ),
                                                    const PopupMenuItem(
                                                      value: 'stats',
                                                      child: Text('Show Stats'),
                                                    ),
                                                    if (bookmarks.isNotEmpty)
                                                      const PopupMenuDivider(),
                                                    ...bookmarks.map(
                                                      (bookmark) =>
                                                          PopupMenuItem(
                                                        value:
                                                            'bookmark_${bookmark.name}',
                                                        child:
                                                            Text(bookmark.name),
                                                      ),
                                                    ),
                                                  ];
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
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

  Widget _buildInfoPill(BuildContext context, String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }

  void _handleNewSession(String sourceName) {
    showDialog(
      context: context,
      builder: (context) => NewSessionDialog(sourceFilter: sourceName),
    );
  }

  void _showStatsDialog(Source source) {
    showDialog(
      context: context,
      builder: (context) => SourceStatsDialog(source: source),
    );
  }

  void _handleBookmark(String bookmarkId, String sourceName) {
    final bookmarkProvider =
        Provider.of<FilterBookmarkProvider>(context, listen: false);
    final bookmark = bookmarkProvider.bookmarks.firstWhere(
      (b) => b.name == bookmarkId,
      orElse: () => FilterBookmark(
        name: '',
        expression: '',
        description: '',
        sorts: [],
      ),
    );

    if (bookmark.name.isEmpty) return;

    // Create a combined filter
    final sourceElement = SourceElement(sourceName, sourceName);
    final bookmarkElement = FilterExpressionParser.parse(bookmark.expression);

    FilterElement combinedFilter;
    if (bookmarkElement != null) {
      combinedFilter = AndElement([sourceElement, bookmarkElement]);
    } else {
      combinedFilter = sourceElement;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionListScreen(
          initialFilter: combinedFilter,
        ),
      ),
    );
  }
}
