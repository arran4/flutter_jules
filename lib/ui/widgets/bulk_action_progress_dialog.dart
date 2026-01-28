import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bulk_action.dart';
import '../../models/session.dart';
import '../../services/bulk_action_executor.dart';
import 'package:intl/intl.dart';
import 'session_summary_tile.dart';

class BulkActionProgressDialog extends StatefulWidget {
  final BulkJobConfig config;
  final List<Session> targets;

  const BulkActionProgressDialog({
    super.key,
    required this.config,
    required this.targets,
  });

  @override
  State<BulkActionProgressDialog> createState() =>
      _BulkActionProgressDialogState();
}

class _BulkActionProgressDialogState extends State<BulkActionProgressDialog> {
  final TextEditingController _delayController = TextEditingController();
  String _delayUnit = 's'; // 'ms', 's', or 'min'

  @override
  void initState() {
    super.initState();
    _delayController.text = widget.config.waitBetween.inSeconds.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BulkActionExecutor>().startJob(
            widget.config,
            widget.targets,
          );
    });
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BulkActionExecutor>(
      builder: (context, executor, child) {
        final total = executor.totalToProcess;
        final completed = executor.completed.length;
        final progress = total > 0 ? completed / total : 0.0;
        final isDone = executor.status == BulkJobStatus.completed ||
            executor.status == BulkJobStatus.canceled;

        return AlertDialog(
          title: Text(isDone ? 'Bulk Job Finished' : 'Executing Bulk Actions'),
          content: SizedBox(
            width: 800,
            height: 600,
            child: Column(
              children: [
                // 1. Dashboard / Stats
                _buildDashboard(executor, progress, completed, total),
                const SizedBox(height: 16),

                // 2. Controls
                if (!isDone) _buildMainControls(executor),
                const SizedBox(height: 16),

                // 3. Log and Queue
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Log
                      Expanded(flex: 1, child: _buildLogView(executor)),
                      const VerticalDivider(width: 32),
                      // Queue
                      Expanded(flex: 1, child: _buildQueueView(executor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!isDone)
              TextButton(
                onPressed: () => _confirmCancel(context, executor),
                child: const Text(
                  'Cancel Job',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (isDone) ...[
              if (executor.logs.any(
                (l) => l.undoActionType != null && !l.isUndone,
              ))
                TextButton(
                  onPressed: () => executor.undoAll(),
                  child: const Text('Undo All'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDashboard(
    BulkActionExecutor executor,
    double progress,
    int completed,
    int total,
  ) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Progress: ${(progress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "$completed / $total sessions processed",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Estimated Time Remaining",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      executor.estimatedTimeRemaining,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.blue.shade100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControls(BulkActionExecutor executor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (executor.status == BulkJobStatus.running)
              FilledButton.icon(
                onPressed: executor.pauseJob,
                icon: const Icon(Icons.pause),
                label: const Text("Pause Job"),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
              )
            else if (executor.status == BulkJobStatus.paused)
              FilledButton.icon(
                onPressed: executor.resumeJob,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Resume Job"),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text("Inter-job Delay:", style: TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _delayController,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _delayUnit,
              isDense: true,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'ms',
                  child: Text('ms', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 's',
                  child: Text('s', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'min',
                  child: Text('min', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _delayUnit = val);
                }
              },
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _applyDelayChange(executor),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Apply'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogView(BulkActionExecutor executor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Activity Log",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.builder(
              itemCount: executor.logs.length,
              itemBuilder: (context, index) {
                final log = executor.logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('HH:mm:ss').format(log.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.message,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      log.isError ? Colors.red : Colors.black87,
                                ),
                              ),
                            ),
                            if (log.undoActionType != null)
                              SizedBox(
                                height: 20,
                                child: TextButton(
                                  onPressed: log.isUndone
                                      ? null
                                      : () => executor.undoLogEntry(log),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    log.isUndone ? "Undone" : "Undo",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueView(BulkActionExecutor executor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Queue (${executor.queue.length} remaining)",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.builder(
              itemCount: executor.queue.length,
              itemBuilder: (context, index) {
                final session = executor.queue[index];
                final isPaused = executor.pausedSessionIds.contains(session.id);

                return GestureDetector(
                  onSecondaryTapUp: (details) => _showQueueItemMenu(
                    context,
                    details.globalPosition,
                    executor,
                    session,
                  ),
                  child: SessionSummaryTile(
                    session: session,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    showPausedLabel: true,
                    isPaused: isPaused,
                    titleStyle: TextStyle(
                      fontSize: 11,
                      color:
                          isPaused ? Colors.orange.shade700 : Colors.black87,
                      fontWeight:
                          isPaused ? FontWeight.w600 : FontWeight.normal,
                    ),
                    subtitleStyle: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                    trailing: isPaused
                        ? const Icon(
                            Icons.pause_circle,
                            size: 18,
                            color: Colors.orange,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showQueueItemMenu(
    BuildContext context,
    Offset position,
    BulkActionExecutor executor,
    Session session,
  ) {
    final isPaused = executor.pausedSessionIds.contains(session.id);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
              const SizedBox(width: 8),
              Text(isPaused ? "Resume" : "Pause"),
            ],
          ),
          onTap: () => executor.togglePauseSession(session.id),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text("Remove", style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => executor.removeFromQueue(session.id),
        ),
      ],
    );
  }

  void _confirmCancel(BuildContext context, BulkActionExecutor executor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Bulk Job'),
        content: const Text(
          'Are you sure you want to stop the remaining operations? The current session being processed will complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, continue'),
          ),
          FilledButton(
            onPressed: () {
              executor.cancelJob();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  void _applyDelayChange(BulkActionExecutor executor) {
    final value = int.tryParse(_delayController.text);
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid delay value')),
      );
      return;
    }

    int delayInSeconds;
    switch (_delayUnit) {
      case 'ms':
        delayInSeconds = (value / 1000).ceil();
        break;
      case 's':
        delayInSeconds = value;
        break;
      case 'min':
        delayInSeconds = value * 60;
        break;
      default:
        delayInSeconds = value;
    }

    executor.waitBetweenSeconds = delayInSeconds;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Delay updated to $delayInSeconds seconds')),
    );
  }
}
