import 'package:flutter/material.dart';
import '../../models.dart';
import '../../services/source_provider.dart';

class SourceStatsDialog extends StatelessWidget {
  final Source source;
  final List<Session> sessions;

  const SourceStatsDialog({
    super.key,
    required this.source,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate Stats
    final totalSessions = sessions.length;
    final Map<SessionState, int> statusCounts = {};
    final Map<String, int> prStatusCounts = {};

    for (final session in sessions) {
      statusCounts[session.state ?? SessionState.STATE_UNSPECIFIED] =
          (statusCounts[session.state ?? SessionState.STATE_UNSPECIFIED] ?? 0) + 1;

      if (session.prStatus != null) {
        prStatusCounts[session.prStatus!] = (prStatusCounts[session.prStatus!] ?? 0) + 1;
      }
    }

    // Sort PR statuses for consistent display
    final sortedPrStatuses = prStatusCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AlertDialog(
      title: Text('Statistics for ${source.name.replaceFirst('sources/github/', '')}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(context, 'Total Sessions', totalSessions.toString()),
              const Divider(),
              const Text('Sessions by Status', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (statusCounts.isEmpty)
                const Text('No sessions found', style: TextStyle(color: Colors.grey)),
              for (final entry in statusCounts.entries)
                if (entry.value > 0)
                  _buildProgressRow(
                    context,
                    entry.key.displayName,
                    entry.value,
                    totalSessions,
                    _getColorForState(entry.key)
                  ),

              const SizedBox(height: 16),
              const Divider(),
              const Text('Sessions by PR Status', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (prStatusCounts.isEmpty)
                const Text('No PRs found', style: TextStyle(color: Colors.grey)),
              for (final entry in sortedPrStatuses)
                _buildProgressRow(
                  context,
                  entry.key,
                  entry.value,
                  totalSessions, // Percentage of total sessions? Or just relative visual
                  _getColorForPrStatus(entry.key)
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressRow(BuildContext context, String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Color _getColorForState(SessionState state) {
    switch (state) {
      case SessionState.COMPLETED:
        return Colors.green;
      case SessionState.FAILED:
        return Colors.red;
      case SessionState.IN_PROGRESS:
        return Colors.blue;
      case SessionState.AWAITING_PLAN_APPROVAL:
        return Colors.orange;
      case SessionState.QUEUED:
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getColorForPrStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'merged') return Colors.purple;
    if (s == 'open') return Colors.green;
    if (s == 'closed') return Colors.red;
    if (s == 'draft') return Colors.amber;
    return Colors.grey;
  }
}
