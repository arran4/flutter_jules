import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models.dart';

class SessionMetaPills extends StatelessWidget {
  final Session session;
  final bool compact;

  const SessionMetaPills({
    super.key,
    required this.session,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only wrap with Wrap if NOT compact.
    // But if we want it to wrap, we should always use Wrap.
    // If compact, maybe smaller icons or fewer items?
    // Let's assume compact just reduces spacing/size.

    return Wrap(
      spacing: compact ? 4.0 : 8.0,
      runSpacing: compact ? 2.0 : 4.0,
      children: [
        // STATE Pill
        if (session.state != null)
          _buildChip(
            label: session.state!.displayName,
            backgroundColor: session.state == SessionState.COMPLETED
                ? Colors.green.shade50
                : (session.state == SessionState.FAILED
                    ? Colors.red.shade50
                    : Colors.grey.shade50),
            avatar: session.state == SessionState.COMPLETED
                ? const Icon(Icons.check, size: 16, color: Colors.green)
                : null,
          ),

        // DATE Pill
        if (session.createTime != null)
          _buildChip(
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: DateFormat.yMMMd()
                .add_jm()
                .format(DateTime.parse(session.createTime!).toLocal()),
          ),

        // Automation Mode
        if (session.automationMode != null)
          _buildChip(
            avatar: const Icon(Icons.smart_toy, size: 16),
            label:
                "Automation: ${session.automationMode.toString().split('.').last.replaceAll('AUTOMATION_MODE_', '')}",
            backgroundColor: Colors.blue.shade50,
          ),

        // Approval
        if (session.requirePlanApproval != null)
          _buildChip(
            label: session.requirePlanApproval!
                ? "Approval Required"
                : "No Approval Required",
            avatar: Icon(
              session.requirePlanApproval!
                  ? Icons.check_circle_outline
                  : Icons.do_not_disturb_on_outlined,
              size: 16,
            ),
            backgroundColor: session.requirePlanApproval!
                ? Colors.orange.shade50
                : Colors.green.shade50,
          ),

        // Source
        _buildChip(
          label: session.sourceContext.source,
          avatar: const Icon(Icons.source, size: 16),
        ),

        // Branch
        if (session.sourceContext.githubRepoContext?.startingBranch != null)
          _buildChip(
            label: session.sourceContext.githubRepoContext!.startingBranch,
            avatar: const Icon(Icons.call_split, size: 16),
          ),
      ],
    );
  }

  Widget _buildChip(
      {required String label, Color? backgroundColor, Widget? avatar}) {
    return Chip(
      label: Text(label, style: compact ? const TextStyle(fontSize: 10) : null),
      backgroundColor: backgroundColor,
      avatar: avatar,
      side: BorderSide.none,
      padding: compact ? const EdgeInsets.all(0) : null,
      visualDensity: compact ? VisualDensity.compact : null,
    );
  }
}
