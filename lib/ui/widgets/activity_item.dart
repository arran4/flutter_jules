import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import 'model_viewer.dart';

class ActivityItem extends StatelessWidget {
  final Activity activity;

  const ActivityItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    String title = "Activity";
    String description = activity.description;
    IconData icon = Icons.info;
    Color? iconColor;

    if (activity.agentMessaged != null) {
      title = "Agent";
      description = activity.agentMessaged!.agentMessage;
      icon = Icons.smart_toy;
      iconColor = Colors.blue;
    } else if (activity.userMessaged != null) {
      title = "User";
      description = activity.userMessaged!.userMessage;
      icon = Icons.person;
      iconColor = Colors.green;
    } else if (activity.planGenerated != null) {
      title = "Plan Generated";
      description =
          "Plan with ${activity.planGenerated!.plan.steps.length} steps created.";
      icon = Icons.list_alt;
      iconColor = Colors.orange;
    } else if (activity.planApproved != null) {
      title = "Plan Approved";
      description = "Plan ID: ${activity.planApproved!.planId}";
      icon = Icons.check_circle;
      iconColor = Colors.teal;
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      description = activity.progressUpdated!.description;
      icon = Icons.update;
      iconColor = Colors.indigo;
    } else if (activity.sessionCompleted != null) {
      title = "Session Completed";
      description = "The session has been completed successfully.";
      icon = Icons.flag;
      iconColor = Colors.green;
    } else if (activity.sessionFailed != null) {
      title = "Session Failed";
      description = activity.sessionFailed!.reason;
      icon = Icons.error;
      iconColor = Colors.red;
    } else if (activity.artifacts != null && activity.artifacts!.isNotEmpty) {
      // Check for BashOutput to determine main icon/title
      final bashArtifact = activity.artifacts!.firstWhere(
        (a) => a.bashOutput != null,
        orElse: () => Artifact(),
      );

      if (bashArtifact.bashOutput != null) {
        final bash = bashArtifact.bashOutput!;
        title = "Command Executed";
        description = "${bash.command}\n${bash.output}";
        if (bash.exitCode != 0) {
          icon = Icons.dangerous;
          iconColor = Colors.red;
        } else {
          icon = Icons.terminal;
          iconColor = Colors.grey;
        }
      } else {
        // Fallback for other artifacts (e.g. only ChangeSet)
        title = "Artifacts";
        description = "${activity.artifacts!.length} items";
        icon = Icons.category;
        iconColor = Colors.blueGrey;
      }
    } else {
      // Fallback for unsupported/unknown types
      title = "Unsupported Activity";
      description = "Type: Unknown\nID: ${activity.id}";
      icon = Icons.help_outline;
      iconColor = Colors.amber;
    }

    // Parse timestamp (assuming ISO 8601)
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
            if (description.isNotEmpty && activity.artifacts == null) ...[
              Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
            ],
            // For artifacts, we might want to show the preview in description/subtitle
            if (activity.artifacts != null && description.isNotEmpty) ...[
              Text(description.split('\n').first,
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
              onSelected: (value) {
                if (value == 'raw_data') {
                  showDialog(
                    context: context,
                    builder: (context) => ModelViewer(
                      data: activity.toJson(),
                      title: 'Activity Data',
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activity.agentMessaged != null ||
                    activity.userMessaged != null ||
                    activity.sessionFailed != null ||
                    activity.progressUpdated != null ||
                    icon == Icons.help_outline) ...[
                  if (description.isNotEmpty) ...[
                    Text("Description:",
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    SelectableText(description),
                    const Divider(),
                  ]
                ],
                // Render Artifacts Detail
                if (activity.artifacts != null) ...[
                  for (var artifact in activity.artifacts!) ...[
                    if (artifact.bashOutput != null) ...[
                      Text("Command:",
                          style: Theme.of(context).textTheme.labelLarge),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: Colors.black12,
                        child: SelectableText(
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
                        child: SelectableText(
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
                    ] else if (artifact.changeSet != null) ...[
                      Text("Change Set:",
                          style: Theme.of(context).textTheme.labelLarge),
                      Text("Source: ${artifact.changeSet!.source}"),
                      const Divider(),
                    ]
                  ]
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
