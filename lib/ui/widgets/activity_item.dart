import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import '../../services/settings_provider.dart';
import 'model_viewer.dart';
import 'activity_helper.dart';

class ActivityItem extends StatefulWidget {
  final Activity activity;
  final Future<void> Function()? onRefresh;

  const ActivityItem({super.key, required this.activity, this.onRefresh});

  @override
  State<ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<ActivityItem> {
  bool _isExpanded = true;

  String? _getPrUrl(ChangeSet changeSet) {
    // Try to get session ID from activity name to link to Jules
    final sessionId = _getSessionIdFromActivityName(widget.activity.name);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (sessionId != null) {
      if (settings.useCorpJulesUrl) {
        return 'https://jules.corp.google.com/session/$sessionId';
      }
      return 'https://jules.google.com/session/$sessionId';
    }

    // Fallback to GitHub URL
    final sourceParts = changeSet.source.split('/');
    if (sourceParts.length >= 4 && sourceParts[1] == 'github') {
      final owner = sourceParts[2];
      final repo = sourceParts[3];
      return 'https://github.com/$owner/$repo/pulls';
    }
    return null;
  }

  String? _getSessionIdFromActivityName(String name) {
    final parts = name.split('/');
    if (parts.length >= 2 && parts[0] == 'sessions') {
      return parts[1];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [_buildHeader(), if (_isExpanded) _buildBody()]),
    );
  }

  Widget _buildMissingMediaDataRow(String mimeType) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.image, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "Image ($mimeType) - No Data",
            style: const TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final activity = widget.activity;
    final info = ActivityDisplayInfo.fromActivity(activity);
    final title = info.title;
    final summary = info.summary;
    final icon = info.icon;
    final iconColor = info.iconColor;
    final isCompactable = info.isCompactable;

    // Timestamp
    DateTime? timestamp;
    try {
      if (activity.createTime.isNotEmpty) {
        timestamp = DateTime.parse(activity.createTime);
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.Hms().format(timestamp.toLocal()),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                if (!_isExpanded && summary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      summary,
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                if (isCompactable && _isExpanded && summary != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(summary, style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () async {
                    await widget.onRefresh!();
                  },
                ),
              Builder(
                builder: (context) {
                  final unknownProps =
                      Map<String, dynamic>.from(widget.activity.unmappedProps)
                        ..remove('isPending')
                        ..remove('hasMismatch')
                        ..remove('pendingId')
                        ..remove('isQueued')
                        ..remove('queueReason')
                        ..remove('processingErrors')
                        ..remove('isSent');

                  if (unknownProps.isNotEmpty) {
                    return IconButton(
                      icon: const Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: Colors.orange,
                      ),
                      tooltip: 'Unknown Properties Found',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Unknown Properties"),
                            content: SingleChildScrollView(
                              child: SelectableText(
                                const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(unknownProps),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (value) async {
                  if (value == 'raw_data') {
                    showDialog(
                      context: context,
                      builder: (context) => ModelViewer(
                        data: widget.activity.toJson(),
                        title: 'Activity Data',
                      ),
                    );
                  } else if (value == 'refresh') {
                    if (widget.onRefresh != null) {
                      await widget.onRefresh!();
                    }
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  if (widget.onRefresh != null)
                    const PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Refresh Activity'),
                        ],
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'raw_data',
                    child: Row(
                      children: [
                        Icon(Icons.data_object, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('View Raw Data'),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isCompactable)
                IconButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final activity = widget.activity;

    // Check if simple message (compacted in header)
    if (activity.artifacts == null || activity.artifacts!.isEmpty) {
      if (activity.agentMessaged != null) {
        final msg = activity.agentMessaged!.agentMessage;
        if (msg.length < 300 && !msg.contains('\n')) {
          return const SizedBox.shrink();
        }
      }
      if (activity.userMessaged != null) {
        final msg = activity.userMessaged!.userMessage;
        if (msg.length < 300 && !msg.contains('\n')) {
          return const SizedBox.shrink();
        }
      }
    }

    // Check for Empty or Unknown
    if (activity.agentMessaged == null &&
        activity.userMessaged == null &&
        activity.progressUpdated == null &&
        (activity.artifacts == null || activity.artifacts!.isEmpty) &&
        activity.planGenerated == null &&
        activity.planApproved == null &&
        activity.sessionCompleted == null &&
        activity.sessionFailed == null) {
      if (activity.description.isEmpty) {
        return const SizedBox.shrink();
      } else {
        // Unknown - Render JSON Tree
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(activity.toJson()),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        );
      }
    }

    bool isCompactArtifact = false;
    if (activity.artifacts != null && activity.artifacts!.isNotEmpty) {
      final changeSet = activity.artifacts!
          .firstWhere((a) => a.changeSet != null, orElse: () => Artifact())
          .changeSet;
      if (changeSet != null &&
          changeSet.gitPatch == null &&
          activity.artifacts!.every(
            (a) =>
                a.bashOutput == null &&
                a.changeSet != null &&
                a.changeSet!.gitPatch == null,
          )) {
        isCompactArtifact = true;
      }
    }

    final hasOtherContent =
        activity.progressUpdated != null ||
        activity.agentMessaged != null ||
        activity.userMessaged != null ||
        activity.unmappedProps.isNotEmpty;

    if (isCompactArtifact && !hasOtherContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activity.progressUpdated != null) ...[
              MarkdownBody(data: activity.progressUpdated!.description),
              const SizedBox(height: 8),
            ],
            if (activity.agentMessaged != null)
              MarkdownBody(data: activity.agentMessaged!.agentMessage),
            if (activity.userMessaged != null)
              MarkdownBody(data: activity.userMessaged!.userMessage),
            if (activity.artifacts != null)
              for (var artifact in activity.artifacts!) ...[
                if (artifact.bashOutput != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "\$ ${artifact.bashOutput!.command}",
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (artifact.bashOutput!.output.isNotEmpty) ...[
                          const Divider(height: 12),
                          Text(
                            artifact.bashOutput!.output,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ],
                        if (artifact.bashOutput!.exitCode != 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Exit Code: ${artifact.bashOutput!.exitCode}",
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (artifact.changeSet != null) ...[
                  if (artifact.changeSet!.gitPatch != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "Change in ${artifact.changeSet!.source}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_getPrUrl(artifact.changeSet!) != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Create PR'),
                              onPressed: () {
                                final url = _getPrUrl(artifact.changeSet!);
                                if (url != null) {
                                  launchUrl(Uri.parse(url));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (artifact
                        .changeSet!
                        .gitPatch!
                        .suggestedCommitMessage
                        .isNotEmpty) ...[
                      const Text(
                        "Commit Message:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          artifact.changeSet!.gitPatch!.suggestedCommitMessage,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      "Patch:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withValues(alpha: 0.05),
                      child: Text(
                        artifact.changeSet!.gitPatch!.unidiffPatch,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        maxLines: 15,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              artifact.changeSet!.source,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (artifact.media != null) ...[
                  if (artifact.media!.data.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        base64Decode(artifact.media!.data),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  "Failed to load image",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    _buildMissingMediaDataRow(artifact.media!.mimeType),
                  ],
                ],
              ],
            if (activity.unmappedProps.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final unknownProps =
                      Map<String, dynamic>.from(activity.unmappedProps)
                        ..remove('isPending')
                        ..remove('hasMismatch')
                        ..remove('pendingId')
                        ..remove('isQueued')
                        ..remove('queueReason')
                        ..remove('processingErrors');

                  if (unknownProps.isEmpty &&
                      (activity.unmappedProps.containsKey('isPending') ||
                          activity.unmappedProps.containsKey('isSent') ||
                          activity.unmappedProps.containsKey('isQueued'))) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (activity.unmappedProps['isPending'] == true)
                          Row(
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Sending...",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (activity.unmappedProps['isSent'] == true)
                          Row(
                            children: [
                              Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Sent",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        if (activity.unmappedProps['isQueued'] == true) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Queued / Failed to Send",
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (activity.unmappedProps['queueReason'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 22),
                              child: Text(
                                "Reason: ${activity.unmappedProps['queueReason']}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (activity.unmappedProps['processingErrors'] !=
                                  null &&
                              (activity.unmappedProps['processingErrors']
                                      as List)
                                  .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((activity
                                              .unmappedProps['processingErrors']
                                          as List)
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.assignment,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          "See Log",
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text("Error Log"),
                                              content: SingleChildScrollView(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children:
                                                      (activity.unmappedProps['processingErrors']
                                                              as List)
                                                          .map<Widget>((e) {
                                                            return Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 8.0,
                                                                  ),
                                                              child: SelectableText(
                                                                "• $e",
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .red,
                                                                  fontFamily:
                                                                      'monospace',
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            );
                                                          })
                                                          .toList(),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text("Close"),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  // Show latest error inline as preview
                                  Text(
                                    "Last Error: ${(activity.unmappedProps['processingErrors'] as List).last}",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    );
                  }

                  if (unknownProps.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Unknown Data:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(unknownProps),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
