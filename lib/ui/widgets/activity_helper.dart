import 'package:flutter/material.dart';
import '../../models.dart';

class ActivityDisplayInfo {
  final String title;
  final String? summary;
  final IconData icon;
  final Color? iconColor;
  final bool isCompactable;

  ActivityDisplayInfo({
    required this.title,
    this.summary,
    required this.icon,
    this.iconColor,
    this.isCompactable = false,
  });

  static ActivityDisplayInfo fromActivity(Activity activity) {
    String title = "Activity";
    String? summary;
    IconData icon = Icons.info;
    Color? iconColor;
    bool isCompactable = false;

    if (activity.sessionFailed != null) {
      title = "Session Failed";
      summary = activity.sessionFailed!.reason;
      icon = Icons.error;
      iconColor = Colors.red;
    } else if (activity.sessionCompleted != null) {
      title = "Session Completed";
      summary = "Success";
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
      title = "User";
      final msg = activity.userMessaged!.userMessage;
      summary = msg;
      if ((activity.artifacts == null || activity.artifacts!.isEmpty) &&
          msg.length < 300 &&
          !msg.contains('\n')) {
        isCompactable = true;
      } else {
        summary = msg.split('\n').first;
      }
      icon = Icons.person;
      iconColor = Colors.green;
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
        final changeSetArtifact = activity.artifacts!.firstWhere(
           (a) => a.changeSet != null,
           orElse: () => Artifact(),
        );

        if (changeSetArtifact.changeSet != null) {
           title = "Artifact";
           summary = "Source: ${changeSetArtifact.changeSet!.source.split('/').last}";
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
    
    return ActivityDisplayInfo(
      title: title,
      summary: summary,
      icon: icon,
      iconColor: iconColor,
      isCompactable: isCompactable,
    );
  }
}

abstract class ActivityListItem {}

class ActivityItemWrapper extends ActivityListItem {
  final Activity activity;
  ActivityItemWrapper(this.activity);
}

class ActivityGroupWrapper extends ActivityListItem {
  final List<Activity> activities;
  final ActivityDisplayInfo info;
  ActivityGroupWrapper(this.activities, this.info);
}
