import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/github_provider.dart';

class GithubQueuePane extends StatelessWidget {
  const GithubQueuePane({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GithubProvider>(
      builder: (context, provider, child) {
        final limit = provider.rateLimitLimit ?? 0;
        final remaining = provider.rateLimitRemaining ?? 0;
        final reset = provider.rateLimitReset;

        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GitHub API Status",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                // Rate Limit Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        "Rate Limit",
                        "$remaining / $limit",
                        Colors.blue,
                        Icons.speed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        "Reset Time",
                        reset != null
                            ? DateFormat.Hms().format(reset)
                            : "--:--",
                        Colors.orange,
                        Icons.timer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        "Wait Time",
                        _formatDuration(provider.waitTime),
                        provider.waitTime.inSeconds > 0
                            ? Colors.red
                            : Colors.green,
                        Icons.hourglass_empty,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                if (provider.queue.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        "Queue is empty",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Processing Queue (${provider.queue.length})",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.queue.length,
                        itemBuilder: (context, index) {
                          final job = provider.queue[index];
                          return ListTile(
                            leading: _buildStatusIcon(job.status),
                            title: Text(job.description),
                            subtitle:
                                Text(job.status.toString().split('.').last),
                            trailing: job.status == GithubJobStatus.running
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : null,
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(GithubJobStatus status) {
    switch (status) {
      case GithubJobStatus.pending:
        return const Icon(Icons.pending_outlined, color: Colors.grey);
      case GithubJobStatus.running:
        return const Icon(Icons.play_circle_outline, color: Colors.blue);
      case GithubJobStatus.completed:
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      case GithubJobStatus.failed:
        return const Icon(Icons.error_outline, color: Colors.red);
    }
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return "0s";
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return "${m}m ${s}s";
  }
}
