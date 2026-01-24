import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/activity_provider.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final activityProvider = Provider.of<ActivityProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Log')),
      body: ListView.builder(
        itemCount: activityProvider.logs.length,
        itemBuilder: (context, index) {
          final log = activityProvider.logs[index];
          return ListTile(
            leading: Text(log.timestamp.toIso8601String()),
            title: Text(log.message),
          );
        },
      ),
    );
  }
}
