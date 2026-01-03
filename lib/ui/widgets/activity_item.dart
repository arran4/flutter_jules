import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models.dart';
import 'model_viewer.dart';

class ActivityItem extends StatefulWidget {
  final Activity activity;
  final Future<void> Function()? onRefresh;

  const ActivityItem({
    super.key,
    required this.activity,
    this.onRefresh,
  });

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
      child: Column(
        children: [
          _buildHeader(),
          if (_isExpanded) _buildBody(),
        ],
      ),
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
      summary = activity.agentMessaged!.agentMessage.split('\n').first;
      icon = Icons.smart_toy;
      iconColor = Colors.blue;
    } else if (activity.userMessaged != null) {
      title = "User";
      summary = activity.userMessaged!.userMessage.split('\n').first;
      icon = Icons.person;
      iconColor = Colors.green;
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      summary = activity.progressUpdated!.description.split('\n').first;
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
           summary = "Source: ${changeSetArtifact.changeSet!.source.split('/').last}";
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
    } else {
      title = "Unknown";
      summary = activity.id;
      icon = Icons.help_outline;
      iconColor = Colors.amber;
    }

    // Timestamp
    DateTime? timestamp;
    try {
      if (activity.createTime.isNotEmpty) {
        timestamp = DateTime.parse(activity.createTime);
      }
    } catch (_) {}

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Padding(
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
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (timestamp != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.Hms().format(timestamp.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ]
                    ],
                  ),
                  // If collapsed OR if it's a "summary-only" view (though we default expanded)
                  // The user said: "when shrunk the view should be different".
                  // So if NOT expanded, show the summary.
                  if (!_isExpanded && summary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey[600])),
                    ),
                    
                   // If "Compactable" (one-liner) and Expanded, we might actually show the info here too?
                   // User: "We could make this almost one line of text".
                   // If isCompactable, we essentially treat title+summary as the whole thing.
                   if (isCompactable && _isExpanded && summary != null)
                     Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(summary, style: const TextStyle(fontSize: 13)),
                     )
                ],
              ),
            ),
            // Actions
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
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final activity = widget.activity;
    
    // If it's "Compactable", the header showed enough. Body is empty.
    // Check "Compactable" logic again or ensure consistency. 
    // Actually, let's just inspect content.
     bool isCompactArtifact = false;
     if (activity.artifacts != null && activity.artifacts!.isNotEmpty) {
        final changeSet = activity.artifacts!.firstWhere((a) => a.changeSet != null, orElse: () => Artifact()).changeSet;
        if (changeSet != null && changeSet.gitPatch == null && activity.artifacts!.every((a) => a.bashOutput == null && a.changeSet != null && a.changeSet!.gitPatch == null)) {
           isCompactArtifact = true;
        }
     }
     
     if (isCompactArtifact) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            if (activity.progressUpdated != null)
               MarkdownBody(data: activity.progressUpdated!.description),
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
                         Text("\$ ${artifact.bashOutput!.command}", style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                         if (artifact.bashOutput!.output.isNotEmpty) ...[
                           const Divider(height: 12),
                           Text(artifact.bashOutput!.output, style: const TextStyle(fontFamily: 'monospace')),
                         ],
                         if (artifact.bashOutput!.exitCode != 0) ...[
                            const SizedBox(height: 4),
                            Text("Exit Code: ${artifact.bashOutput!.exitCode}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                         ]
                       ],
                     )
                   ),
                   const SizedBox(height: 8),
                ],
                if (artifact.changeSet != null) ...[
                   // If complex changeset (with patch)
                   if (artifact.changeSet!.gitPatch != null) ...[
                      Text("Change in ${artifact.changeSet!.source}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                         padding: const EdgeInsets.all(8),
                         color: Colors.black.withValues(alpha: 0.05),
                         child: Text(artifact.changeSet!.gitPatch!.unidiffPatch, style: const TextStyle(fontFamily: 'monospace', fontSize: 11), maxLines: 15, overflow: TextOverflow.ellipsis),
                      ),
                       const SizedBox(height: 8),
                   ]
                ]
              ]
          ],
        ),
      ),
    );
  }
}
