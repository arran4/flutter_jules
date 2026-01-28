import 'package:flutter/material.dart';
import '../../models/session.dart';

class SessionSummaryTile extends StatelessWidget {
  final Session session;
  final bool dense;
  final VisualDensity? visualDensity;
  final bool showPausedLabel;
  final bool isPaused;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final Widget? trailing;

  const SessionSummaryTile({
    super.key,
    required this.session,
    this.dense = false,
    this.visualDensity,
    this.showPausedLabel = false,
    this.isPaused = false,
    this.titleStyle,
    this.subtitleStyle,
    this.trailing,
  });

  String _formatSessionId(String id) {
    if (id.length <= 20) {
      return id;
    }

    return '${id.substring(0, 10)}...${id.substring(id.length - 10)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = session.id.startsWith('DRAFT_CREATION_');
    final titleSuffix = StringBuffer();

    if (isDraft) {
      titleSuffix.write(' (Draft)');
    }

    if (showPausedLabel && isPaused) {
      titleSuffix.write(' [PAUSED]');
    }

    return ListTile(
      dense: dense,
      visualDensity: visualDensity,
      title: Text(
        '${session.title ?? session.name}${titleSuffix.toString()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      ),
      subtitle: Text(
        'ID: ${_formatSessionId(session.id)} • ${session.state?.displayName ?? 'Unknown'}',
        style: subtitleStyle,
      ),
      trailing: trailing,
    );
  }
}
