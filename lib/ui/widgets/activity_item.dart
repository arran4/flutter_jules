import 'package:flutter/material.dart';
import '../../models.dart';

class ActivityItem extends StatelessWidget {
  final Activity activity;

  const ActivityItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    String title = "Activity";
    String description = activity.description;
    IconData icon = Icons.info;

    if (activity.agentMessaged != null) {
      title = "Agent";
      description = activity.agentMessaged!.agentMessage;
      icon = Icons.smart_toy;
    } else if (activity.userMessaged != null) {
      title = "User";
      description = activity.userMessaged!.userMessage;
      icon = Icons.person;
    } else if (activity.planGenerated != null) {
      title = "Plan Generated";
      description = "Steps: ${activity.planGenerated!.plan.steps.length}";
      icon = Icons.list_alt;
    } else if (activity.planApproved != null) {
      title = "Plan Approved";
      icon = Icons.check_circle;
    } else if (activity.progressUpdated != null) {
      title = activity.progressUpdated!.title;
      description = activity.progressUpdated!.description;
      icon = Icons.update;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}
