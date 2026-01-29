import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/session.dart';
import '../../models/activity.dart';

class CombinedDataViewer extends StatelessWidget {
  final Session session;
  final List<Activity> activities;

  const CombinedDataViewer({
    super.key,
    required this.session,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Session Data'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Session'),
                Tab(text: 'Activities'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _JsonView(data: session.toJson()),
              _ActivityListView(activities: activities),
            ],
          ),
        ),
      ),
    );
  }
}

class _JsonView extends StatelessWidget {
  final Map<String, dynamic> data;

  const _JsonView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: SelectableText(
          _formatJson(data),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return 'Error formatting JSON: $e';
    }
  }
}

class _ActivityListView extends StatelessWidget {
  final List<Activity> activities;

  const _ActivityListView({required this.activities});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            title: Text(activity.id),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.createTime, style: const TextStyle(fontSize: 12)),
                if (activity.description.isNotEmpty)
                  Text(
                    activity.description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            children: [_JsonView(data: activity.toJson())],
          ),
        );
      },
    );
  }
}

class _ActivityCardBody extends StatelessWidget {
  final Activity activity;

  const _ActivityCardBody({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(activity.id),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activity.createTime, style: const TextStyle(fontSize: 12)),
          if (activity.description.isNotEmpty)
            Text(
              activity.description,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
        ],
      ),
      children: [_JsonView(data: activity.toJson())],
    );
  }
}
