import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../models.dart';

class SourceMetadataDialog extends StatelessWidget {
  final Source source;
  final CacheMetadata? cacheMetadata;
  final File? cacheFile;
  final String? rawContent;

  const SourceMetadataDialog({
    super.key,
    required this.source,
    this.cacheMetadata,
    this.cacheFile,
    this.rawContent,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Source Metadata'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cacheFile != null) _buildLocalCacheSection(context),
              if (cacheMetadata != null) _buildCacheMetadataSection(context),
              _buildSourceDetailsSection(context),
              if (source.githubRepo != null)
                _buildGitHubDetailsSection(context),
              if (source.options != null && source.options!.isNotEmpty)
                _buildOptionsSection(context),
              if (rawContent != null) _buildRawContentSection(context),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildLocalCacheSection(BuildContext context) {
    if (cacheFile == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Local Cache File'),
        _buildCacheFileRow(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCacheMetadataSection(BuildContext context) {
    if (cacheMetadata == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Cache Metadata'),
        _buildCacheMetadataTable(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSourceDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Source Details'),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _buildRow('Name', source.name),
            _buildRow('ID', source.id),
            _buildRow('Archived', source.isArchived.toString()),
            _buildRow('Read-Only', source.isReadOnly.toString()),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGitHubDetailsSection(BuildContext context) {
    final repo = source.githubRepo!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'GitHub Repository'),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            _buildRow('Owner', repo.owner),
            _buildRow('Repo', repo.repo),
            _buildRow('Description', repo.description ?? 'N/A'),
            _buildRow('Private (Jules)', repo.isPrivate.toString()),
            if (repo.isPrivateGithub != null)
              _buildRow('Private (GitHub)', repo.isPrivateGithub.toString()),
            if (repo.htmlUrl != null) _buildRow('HTML URL', repo.htmlUrl!),
            if (repo.primaryLanguage != null)
              _buildRow('Language', repo.primaryLanguage!),
            if (repo.license != null) _buildRow('License', repo.license!),
            if (repo.isFork != null)
              _buildRow('Is Fork', repo.isFork.toString()),
            if (repo.forkParent != null)
              _buildRow('Fork Parent', repo.forkParent!),
            if (repo.openIssuesCount != null)
              _buildRow('Open Issues', repo.openIssuesCount.toString()),
            if (repo.defaultBranch != null)
              _buildRow('Default Branch', repo.defaultBranch!.displayName),
            if (repo.branches != null)
              _buildRow('Branches', '${repo.branches!.length} found'),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOptionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Options'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SelectableText(
            _formatJson(source.options!),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRawContentSection(BuildContext context) {
    String content = rawContent!;
    try {
      final json = jsonDecode(content);
      content = _formatJson(json);
    } catch (_) {
      // Use raw content if not valid JSON
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Raw Content'),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildCacheFileRow(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              cacheFile!.path,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Path'),
                  onPressed: () => _copyCacheFilePath(context),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.description, size: 16),
                  label: const Text('Open File'),
                  onPressed: () => _openCacheFile(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheMetadataTable(BuildContext context) {
    final m = cacheMetadata!;
    final rows = [
      _buildRow('First Seen', _formatDate(m.firstSeen)),
      _buildRow('Last Retrieved', _formatDate(m.lastRetrieved)),
      if (m.lastOpened != null)
        _buildRow('Last Opened', _formatDate(m.lastOpened!)),
      if (m.lastUpdated != null)
        _buildRow('Last Updated', _formatDate(m.lastUpdated!)),
      _buildRow('Is Watched', m.isWatched.toString()),
      _buildRow('Is Hidden', m.isHidden.toString()),
      if (m.reasonForLastUnread != null)
        _buildRow('Unread Reason', m.reasonForLastUnread!),
    ];

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  TableRow _buildRow(String key, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            key,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SelectableText(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }

  String _formatJson(dynamic json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  void _copyCacheFilePath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: cacheFile!.path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Path copied')),
    );
  }

  Future<void> _openCacheFile(BuildContext context) async {
    try {
      final fileUri = Uri.file(cacheFile!.path);
      final openedFile = await _launchUriIfPossible(fileUri);
      if (openedFile) return;

      final dirUri = Uri.directory(cacheFile!.parent.path);
      final openedDir = await _launchUriIfPossible(dirUri);
      if (!context.mounted) return;

      if (!openedDir) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open file or directory')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<bool> _launchUriIfPossible(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    await launchUrl(uri);
    return true;
  }
}
