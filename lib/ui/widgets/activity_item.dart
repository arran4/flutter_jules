import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models.dart';
import 'model_viewer.dart';

class ActivityItem extends StatefulWidget {
  final Activity activity;
  final Future<void> Function()? onRefresh;

  const ActivityItem({super.key, required this.activity, this.onRefresh});

  @override
  State<ActivityItem> createState() => _ActivityItemState();
}

class _ActivityItemState extends State<ActivityItem> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [_buildHeader(), if (_isExpanded) _buildBody()]),
    );
  }

  Widget _buildHeader() {
    final activity = widget.activity;
    String title = "Activity";
    String? summary;
    IconData icon = Icons.info;
    Color? iconColor;
    bool isCompactable = false;

    // Type Detection Logic (Simplified for Header)
    if (activity.sessionFailed != null) {
      title = "Session Failed";
      summary = activity.sessionFailed!.reason;
      icon = Icons.error;
      iconColor = Colors.red;
    } else if (activity.sessionCompleted != null) {
      title = "Session Completed";
      icon = Icons.flag;
      iconColor = Colors.green;
    } else if (activity.planApproved != null) {
      title = "Plan Approved";
      summary = "Plan ID: ${activity.planApproved!.planId}";
      icon = Icons.check_circle;
      iconColor = Colors.teal;
    } else if (activity.planGenerated != null) {
      title = "Plan Generated";
      summary = "${activity.planGenerated!.plan.steps.length} steps";
      icon = Icons.list_alt;
      iconColor = Colors.orange;
    } else if (activity.agentMessaged != null) {
      title = "Agent";
      final msg = activity.agentMessaged!.agentMessage;
      summary = msg;
      if ((activity.artifacts == null || activity.artifacts!.isEmpty) &&
          msg.length < 300 &&
          !msg.contains('\n')) {
        isCompactable = true;
      } else {
        summary = msg.split('\n').first;
      }
      icon = Icons.smart_toy;
      iconColor = Colors.blue;
    } else if (activity.userMessaged != null) {
      final isPending = activity.unmappedProps['isPending'] == true;
      final isQueued = activity.unmappedProps['isQueued'] == true;
      if (isPending) {
        title = "Sending...";
        icon = Icons.hourglass_empty;
        iconColor = Colors.grey;
      } else if (isQueued) {
        title = "Sending Failed";
        icon = Icons.cloud_off;
        iconColor = Colors.orange;
      } else {
        title = "User";
        icon = Icons.person;
        iconColor = Colors.green;
      }
      final msg = activity.userMessaged!.userMessage;
      summary = msg;
      if ((activity.artifacts == null || activity.artifacts!.isEmpty) &&
          msg.length < 300 &&
          !msg.contains('\n')) {
        isCompactable = true;
      } else {
        summary = msg.split('\n').first;
      }
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      summary = activity.progressUpdated!.description;
      if ((activity.artifacts == null || activity.artifacts!.isEmpty) &&
          summary.length < 300 &&
          !summary.contains('\n')) {
        isCompactable = true;
      }
      icon = Icons.update;
      iconColor = Colors.indigo;
    } else if (activity.artifacts != null && activity.artifacts!.isNotEmpty) {
      // Artifact Logic
      final bashArtifact = activity.artifacts!.firstWhere(
        (a) => a.bashOutput != null,
        orElse: () => Artifact(),
      );

      if (bashArtifact.bashOutput != null) {
        title = "Command";
        summary = bashArtifact.bashOutput!.command;
        if (bashArtifact.bashOutput!.exitCode != 0) {
          icon = Icons.dangerous;
          iconColor = Colors.red;
        } else {
          icon = Icons.terminal;
          iconColor = Colors.grey;
        }
      } else {
        // Just generic artifacts (e.g. ChangeSet)
        // Check if it's the "Simple ChangeSet" case
        final changeSetArtifact = activity.artifacts!.firstWhere(
          (a) => a.changeSet != null,
          orElse: () => Artifact(),
        );

        if (changeSetArtifact.changeSet != null) {
          title = "Artifact";
          summary =
              "Source: ${changeSetArtifact.changeSet!.source.split('/').last}";
          // If it has no patch, it's very compactable
          if (changeSetArtifact.changeSet!.gitPatch == null) {
            isCompactable = true;
          }
        } else {
          title = "Artifacts";
          summary = "${activity.artifacts!.length} items";
        }
        icon = Icons.category;
        iconColor = Colors.blueGrey;
      }
    } else if (activity.sessionCompleted != null) {
      title = "Session Completed";
      summary = "Success";
      icon = Icons.flag;
      iconColor = Colors.green;
    } else {
      if (activity.description.isEmpty) {
        title = "Empty Activity";
        summary = "${activity.originator ?? 'Unknown'} • ${activity.id}";
        isCompactable = true;
        icon = Icons.crop_square;
        iconColor = Colors.grey;
      } else {
        title = "Unknown";
        summary = activity.description;
        icon = Icons.help_outline;
        iconColor = Colors.amber;
      }
    }

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
                        ..remove('processingErrors');

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

    final hasOtherContent = activity.progressUpdated != null ||
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
            if (activity.planGenerated != null)
              ...activity.planGenerated!.plan.steps.map(
                (step) => ListTile(
                  leading: CircleAvatar(child: Text('${step.index ?? 0 + 1}')),
                  title: Text(step.title),
                  subtitle: step.description != null
                      ? Text(step.description!)
                      : null,
                ),
              ),
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
                    Text(
                      "Change in ${artifact.changeSet!.source}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withValues(alpha: 0.05),
                      child: MarkdownBody(
                        data:
                            "```diff\n${artifact.changeSet!.gitPatch!.unidiffPatch}\n```",
                        styleSheet: MarkdownStyleSheet(
                          code: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
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
                  if (artifact.media!.data.isNotEmpty)
                    Image.memory(
                      base64Decode(artifact.media!.data),
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
                    )
                ]
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
                                children:
                                    (activity.unmappedProps['processingErrors']
                                            as List)
                                        .map<Widget>(
                                          (e) => Text(
                                            "• $e",
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                        .toList(),
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
