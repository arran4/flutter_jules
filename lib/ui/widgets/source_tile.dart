import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models.dart';
import '../../services/auth_provider.dart';
import '../../services/filter_bookmark_provider.dart';
import '../../services/github_provider.dart';
import '../../services/session_provider.dart';
import '../../services/source_provider.dart';
import '../screens/session_list_screen.dart';
import 'new_session_dialog.dart';
import 'source_stats_dialog.dart';
import 'package:flutter_jules/models/filter_expression_parser.dart';
import '../../services/cache_service.dart';
import 'session_metadata_dialog.dart';

class SourceTile extends StatelessWidget {
  final CachedItem<Source> item;
  final int usageCount;
  final DateTime? lastUsedDate;

  const SourceTile({
    super.key,
    required this.item,
    required this.usageCount,
    this.lastUsedDate,
  });

  @override
  Widget build(BuildContext context) {
    final source = item.data;
    final repo = source.githubRepo;
    final isPrivate = repo?.isPrivate ?? false;
    final defaultBranch = repo?.defaultBranch?.displayName ?? 'N/A';
    final branchCount = repo?.branches?.length;
    final description = _buildDescription(context, repo);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(isPrivate ? Icons.lock : Icons.public),
        title: Row(
          children: [
            if (isPrivate)
              const Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Icon(Icons.lock, size: 16, color: Colors.grey),
              ),
            Expanded(
              child: Text(
                repo?.repo ?? source.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null) description,
            _buildRepoStatsRow(repo, defaultBranch, branchCount),
            const SizedBox(height: 4),
            Row(
              children: [
                if (repo?.primaryLanguage != null)
                  _buildInfoPill(context, repo!.primaryLanguage!, Icons.code),
                if (repo?.openIssuesCount != null && repo!.openIssuesCount! > 0)
                  _buildInfoPill(
                    context,
                    '${repo.openIssuesCount} open issues',
                    Icons.bug_report,
                  ),
                if (repo?.isFork ?? false)
                  _buildInfoPill(context, 'Fork', Icons.call_split),
                if (item.metadata.isNew)
                  _buildStatusPill(context, 'NEW', Colors.green),
              ],
            ),
            const SizedBox(height: 4),
            _buildUsageRow(context),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh source',
              onPressed: () => _handleRefreshSource(context, source),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New session',
              onPressed: () => _handleNewSession(context, source.name),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter by this source',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SessionListScreen(sourceFilter: source.name),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleMenuSelection(context, value, source),
              itemBuilder: (context) {
                final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
                  context,
                  listen: false,
                );
                final bookmarks = bookmarkProvider.bookmarks;

                return [
                  const PopupMenuItem(
                    value: 'refresh_sessions',
                    child: Text('Refresh Sessions'),
                  ),
                  const PopupMenuItem(
                    value: 'stats',
                    child: Text('Show Stats'),
                  ),
                  const PopupMenuItem(
                    value: 'view_cache_file',
                    child: Text('View Cache File'),
                  ),
                  if (bookmarks.isNotEmpty) const PopupMenuDivider(),
                  ...bookmarks.map(
                    (bookmark) => PopupMenuItem(
                      value: 'bookmark_${bookmark.name}',
                      child: Text(bookmark.name),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildDescription(BuildContext context, GithubRepo? repo) {
    if (repo?.description == null || repo!.description!.isEmpty) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        repo.description!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildRepoStatsRow(
    GithubRepo? repo,
    String defaultBranch,
    int? branchCount,
  ) {
    return Text(
      '${repo?.owner ?? "Unknown Owner"} • $defaultBranch${branchCount != null ? " • $branchCount branches" : ""}',
    );
  }

  Widget _buildUsageRow(BuildContext context) {
    return Row(
      children: [
        if (usageCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$usageCount sessions',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        if (usageCount > 0) const SizedBox(width: 8),
        if (lastUsedDate != null)
          Text(
            'Last used: ${DateFormat.yMMMd().format(lastUsedDate!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  void _handleRefreshSource(BuildContext context, Source source) async {
    final sourceProvider = Provider.of<SourceProvider>(context, listen: false);
    final githubProvider = Provider.of<GithubProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await sourceProvider.refreshSource(
        source,
        authToken: auth.token,
        githubProvider: githubProvider,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refreshed ${source.githubRepo?.repo ?? source.name}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to refresh ${source.githubRepo?.repo ?? source.name}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleNewSession(BuildContext context, String sourceName) {
    showDialog(
      context: context,
      builder: (context) => NewSessionDialog(sourceFilter: sourceName),
    );
  }

  void _handleMenuSelection(
    BuildContext context,
    String value,
    Source source,
  ) async {
    if (value == 'refresh_sessions') {
      _handleRefreshSessions(context, source);
    } else if (value == 'stats') {
      _showStatsDialog(context, source);
    } else if (value == 'view_cache_file') {
      _handleViewCacheFile(context, source);
    } else if (value.startsWith('bookmark_')) {
      final bookmarkId = value.substring('bookmark_'.length);
      _handleBookmark(context, bookmarkId, source.name);
    }
  }

  void _handleViewCacheFile(BuildContext context, Source source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cacheService = Provider.of<CacheService>(context, listen: false);

    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required')),
      );
      return;
    }

    try {
      final cacheFile =
          await cacheService.getSourceCacheFile(auth.token!, source.id);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => SessionMetadataDialog(
            session: Session(
              id: source.id,
              name: source.name,
              prompt: '',
              sourceContext: SourceContext(source: source.name),
            ),
            cacheMetadata: item.metadata,
            cacheFile: cacheFile,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error retrieving cache file: $e')),
        );
      }
    }
  }

  void _handleRefreshSessions(BuildContext context, Source source) async {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await sessionProvider.refreshSessionsForSource(
        auth.client,
        source.name,
        authToken: auth.token!,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refreshed sessions for ${source.githubRepo?.repo ?? source.name}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to refresh sessions for ${source.githubRepo?.repo ?? source.name}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatsDialog(BuildContext context, Source source) {
    showDialog(
      context: context,
      builder: (context) => SourceStatsDialog(source: source),
    );
  }

  void _handleBookmark(
    BuildContext context,
    String bookmarkId,
    String sourceName,
  ) {
    final bookmarkProvider = Provider.of<FilterBookmarkProvider>(
      context,
      listen: false,
    );
    final bookmark = bookmarkProvider.bookmarks.firstWhere(
      (b) => b.name == bookmarkId,
      orElse: () =>
          FilterBookmark(name: '', expression: '', description: '', sorts: []),
    );

    if (bookmark.name.isEmpty) return;

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
        builder: (context) => SessionListScreen(initialFilter: combinedFilter),
      ),
    );
  }
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
