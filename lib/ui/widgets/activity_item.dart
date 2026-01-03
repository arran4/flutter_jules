import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models.dart';
import 'model_viewer.dart';

class ActivityItem extends StatelessWidget {
  final Activity activity;
  final Future<void> Function()? onRefresh;

  const ActivityItem({
    super.key,
    required this.activity,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method preamble) ...
    String title = "Activity";
    // We will build up the description widget list dynamically or use a main description string
    String? plainDescription;
    IconData icon = Icons.info;
    Color? iconColor;

    // Determine primary specific type for Icon and Title
    bool isKnownType = false;

    if (activity.sessionFailed != null) {
      // ... (existing logic) ...
      title = "Session Failed";
      plainDescription = activity.sessionFailed!.reason;
      icon = Icons.error;
      iconColor = Colors.red;
      isKnownType = true;
    } else if (activity.sessionCompleted != null) {
      title = "Session Completed";
      plainDescription = "The session has been completed successfully.";
      icon = Icons.flag;
      iconColor = Colors.green;
      isKnownType = true;
    } else if (activity.planApproved != null) {
      title = "Plan Approved";
      plainDescription = "Plan ID: ${activity.planApproved!.planId}";
      icon = Icons.check_circle;
      iconColor = Colors.teal;
      isKnownType = true;
    } else if (activity.planGenerated != null) {
      title = "Plan Generated";
      plainDescription =
          "Plan with ${activity.planGenerated!.plan.steps.length} steps created.";
      icon = Icons.list_alt;
      iconColor = Colors.orange;
      isKnownType = true;
    } else if (activity.agentMessaged != null) {
      title = "Agent";
      plainDescription = activity.agentMessaged!.agentMessage;
      icon = Icons.smart_toy;
      iconColor = Colors.blue;
      isKnownType = true;
    } else if (activity.userMessaged != null) {
      title = "User";
      plainDescription = activity.userMessaged!.userMessage;
      icon = Icons.person;
      iconColor = Colors.green;
      isKnownType = true;
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      // progressUpdated description can be markdown
      plainDescription = activity.progressUpdated!.description; 
      icon = Icons.update;
      iconColor = Colors.indigo;
      isKnownType = true;
    }

    // Artifacts handling for Icon/Title if no other specific type
    if (!isKnownType &&
        activity.artifacts != null &&
        activity.artifacts!.isNotEmpty) {
      // Check for BashOutput to determine main icon/title
      final bashArtifact = activity.artifacts!.firstWhere(
        (a) => a.bashOutput != null,
        orElse: () => Artifact(),
      );

      if (bashArtifact.bashOutput != null) {
        final bash = bashArtifact.bashOutput!;
        title = "Command Executed";
        plainDescription = "${bash.command}\n${bash.output}";
        
        if (bash.exitCode != 0) {
          icon = Icons.dangerous;
          iconColor = Colors.red;
        } else {
          icon = Icons.terminal;
          iconColor = Colors.grey;
        }
        isKnownType = true;
      } else {
        // Fallback for other artifacts (e.g. only ChangeSet)
        title = "Artifacts";
        plainDescription = "${activity.artifacts!.length} items";
        icon = Icons.category;
        iconColor = Colors.blueGrey;
        isKnownType = true;
      }
    }

    if (!isKnownType) {
      title = "Unsupported Activity";
      plainDescription = "Type: Unknown\nID: ${activity.id}";
      icon = Icons.help_outline;
      iconColor = Colors.amber;
    }

    // Parse timestamp
    DateTime? timestamp;
    try {
      if (activity.createTime.isNotEmpty) {
        timestamp = DateTime.parse(activity.createTime);
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plainDescription != null && activity.artifacts == null && activity.progressUpdated == null) ...[
              Text(plainDescription, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
            ],
            // Special preview for progress updated (markdown treated as text for preview 3 lines)
            if (activity.progressUpdated != null) ...[
               Text(activity.progressUpdated!.description, maxLines: 3, overflow: TextOverflow.ellipsis),
               const SizedBox(height: 4),
            ],
             // Special preview for artifacts
             if (activity.artifacts != null && plainDescription != null && !title.startsWith("Command")) ...[
                Text(plainDescription.split('\n').first,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: const TextStyle(fontFamily: 'monospace')),
                const SizedBox(height: 4),
             ],
            if (timestamp != null)
              Text(
                DateFormat.yMMMd().add_jm().format(timestamp.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Options',
              onSelected: (value) async {
                if (value == 'raw_data') {
                  showDialog(
                    context: context,
                    builder: (context) => ModelViewer(
                      data: activity.toJson(),
                      title: 'Activity Data',
                    ),
                  );
                } else if (value == 'refresh') {
                  if (onRefresh != null) {
                    await onRefresh!();
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (onRefresh != null)
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
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Description / Message / Progress
                  if (activity.progressUpdated != null) ...[
                     Text("Update:", style: Theme.of(context).textTheme.labelLarge),
                     const SizedBox(height: 8),
                     MarkdownBody(data: activity.progressUpdated!.description),
                     const Divider(),
                  ] else if (activity.agentMessaged != null) ...[
                     Text("Message:", style: Theme.of(context).textTheme.labelLarge),
                     const SizedBox(height: 8),
                     MarkdownBody(data: activity.agentMessaged!.agentMessage),
                     const Divider(),
                  ] else if (activity.userMessaged != null) ...[
                     Text("Message:", style: Theme.of(context).textTheme.labelLarge),
                     const SizedBox(height: 8),
                     MarkdownBody(data: activity.userMessaged!.userMessage),
                     const Divider(),
                  ] else if (isKnownType && plainDescription != null && !title.startsWith("Command") && plainDescription != "Artifacts") ...[
                      Text("Description:", style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(plainDescription),
                      const Divider(),
                  ],
                  // 2. Artifacts
                  if (activity.artifacts != null) ...[
                    for (var artifact in activity.artifacts!) ...[
                      // Bash Output
                      if (artifact.bashOutput != null) ...[
                        Text("Command:",
                            style: Theme.of(context).textTheme.labelLarge),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.black12,
                          child: Text(
                            artifact.bashOutput!.command,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text("Output:",
                            style: Theme.of(context).textTheme.labelLarge),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.black12,
                          child: Text(
                            artifact.bashOutput!.output,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                        if (artifact.bashOutput!.exitCode != 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              "Exit Code: ${artifact.bashOutput!.exitCode}",
                              style: const TextStyle(
                                  color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Divider(),
                      ],
                      // ChangeSet / GitPatch
                      if (artifact.changeSet != null) ...[
                        Text("Change Set:",
                            style: Theme.of(context).textTheme.labelLarge),
                        Text("Source: ${artifact.changeSet!.source}"),
                        if (artifact.changeSet!.gitPatch != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            color: Colors.black12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Commit Message:",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  artifact.changeSet!.gitPatch!
                                      .suggestedCommitMessage,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Base Commit: ${artifact.changeSet!.gitPatch!.baseCommitId.substring(0, 8)}...",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                const Text("Patch Preview:"),
                                Text(
                                  artifact.changeSet!.gitPatch!.unidiffPatch,
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 12),
                                  maxLines: 10,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(),
                      ]
                    ]
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
