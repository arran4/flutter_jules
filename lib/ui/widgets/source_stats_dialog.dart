import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../services/session_provider.dart';

class SourceStatsDialog extends StatelessWidget {
  final Source source;

  const SourceStatsDialog({super.key, required this.source});

  @override
  Widget build(BuildContext context) {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final allSessions = sessionProvider.items;

    final sourceSessions = allSessions
        .where((item) => item.data.sourceContext?.source == source.name)
        .toList();

    final statusCounts = <SessionState, int>{};
    for (final session in sourceSessions) {
      final state = session.data.state ?? SessionState.STATE_UNSPECIFIED;
      statusCounts[state] = (statusCounts[state] ?? 0) + 1;
    }

    final sortedStatuses = statusCounts.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return AlertDialog(
      title: Text('Statistics for ${source.githubRepo?.repo ?? source.name}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('Total Sessions: ${sourceSessions.length}'),
            const SizedBox(height: 16),
            const Text('Sessions by Status:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...sortedStatuses.map((status) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(status.displayName),
                    Text(statusCounts[status].toString()),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
