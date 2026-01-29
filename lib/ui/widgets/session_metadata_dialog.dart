import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import 'package:intl/intl.dart';

class SessionMetadataDialog extends StatelessWidget {
  final Session session;
  final CacheMetadata? cacheMetadata;
  final File? cacheFile;

  const SessionMetadataDialog({
    super.key,
    required this.session,
    this.cacheMetadata,
    this.cacheFile,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session Metadata'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cacheFile != null) _buildLocalCacheSection(context),
              if (cacheMetadata != null) _buildCacheMetadataSection(context),
              _buildServerMetadataSection(context),
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
    if (cacheFile == null) {
      return const SizedBox.shrink();
    }

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
    if (cacheMetadata == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Cache Metadata'),
        _buildCacheMetadataTable(context),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildServerMetadataSection(BuildContext context) {
    if (session.metadata == null || session.metadata!.isEmpty) {
      return const Text(
        "No server metadata available.",
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Server Metadata'),
        _buildServerMetadataTable(context),
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

  Widget _buildServerMetadataTable(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children:
          session.metadata!.map((m) => _buildRow(m.key, m.value)).toList(),
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

  void _copyCacheFilePath(BuildContext context) {
    Clipboard.setData(ClipboardData(text: cacheFile!.path));
    _showSnackBar(context, const Text('Path copied'));
  }

  Future<void> _openCacheFile(BuildContext context) async {
    try {
      final fileUri = Uri.file(cacheFile!.path);
      final openedFile = await _launchUriIfPossible(fileUri);
      if (openedFile) {
        return;
      }

      final dirUri = Uri.directory(cacheFile!.parent.path);
      final openedDir = await _launchUriIfPossible(dirUri);
      if (!openedDir) {
        _showSnackBar(context, const Text('Cannot open file or directory'));
      }
    } catch (e) {
      _showSnackBar(context, Text('Error opening file: $e'));
    }
  }

  Future<bool> _launchUriIfPossible(Uri uri) async {
    if (!await canLaunchUrl(uri)) {
      return false;
    }

    await launchUrl(uri);
    return true;
  }

  void _showSnackBar(BuildContext context, Widget content) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: content));
  }
}
