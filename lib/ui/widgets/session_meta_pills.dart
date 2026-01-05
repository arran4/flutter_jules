import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models.dart';
import '../../models/search_filter.dart';

class SessionMetaPills extends StatelessWidget {
  final Session session;
  final bool compact;
  final Function(FilterToken)? onAddFilter;
  final Function(SortOption)? onAddSort;

  const SessionMetaPills({
    super.key,
    required this.session,
    this.compact = false,
    this.onAddFilter,
    this.onAddSort,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 4.0 : 8.0,
      runSpacing: compact ? 2.0 : 4.0,
      children: [
        // STATE Pill
        if (session.state != null)
          _buildChip(
            context,
            label: session.state!.displayName,
            backgroundColor: _getColorForState(session.state!),
            avatar: session.state == SessionState.COMPLETED
                ? const Icon(Icons.check, size: 16, color: Colors.green)
                : null,
            filterToken: FilterToken(
                id: 'status:${session.state!.name}',
                type: FilterType.status,
                label: session.state!.displayName,
                value: session.state!),
            sortField: SortField.status,
          ),

        // DATE Pill (Created)
        if (session.createTime != null)
          _buildChip(
            context,
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: DateFormat.yMMMd()
                .add_jm()
                .format(DateTime.parse(session.createTime!).toLocal()),
            sortField: SortField.created,
          ),

        // DATE Pill (Updated) - Only if significantly different from created?
        // Let's just show it if updated exists and is not same instant (roughly)
        if (session.updateTime != null &&
            session.createTime != session.updateTime)
          _buildChip(
            context,
            avatar: const Icon(Icons.update, size: 16),
            label:
                "Updated ${DateFormat.yMMMd().add_jm().format(DateTime.parse(session.updateTime!).toLocal())}",
            sortField: SortField.updated,
          ),

        // Automation Mode
        if (session.automationMode != null &&
            session.automationMode !=
                AutomationMode.AUTOMATION_MODE_UNSPECIFIED)
          _buildChip(
            context,
            avatar: const Icon(Icons.smart_toy, size: 16),
            label:
                "Auto: ${session.automationMode.toString().split('.').last.replaceAll('AUTOMATION_MODE_', '')}",
            backgroundColor: Colors.blue.shade50,
          ),

        // Approval
        if (session.requirePlanApproval != null)
          _buildChip(
            context,
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
            filterToken: FilterToken(
                id: 'flag:approval',
                type: FilterType.flag,
                label: session.requirePlanApproval!
                    ? 'Approval Required'
                    : 'No Approval',
                value: session.requirePlanApproval!
                    ? 'approval_required'
                    : 'no_approval'),
          ),

        // Source
        _buildChip(
          context,
          label: session.sourceContext.source,
          avatar: const Icon(Icons.source, size: 16),
          filterToken: FilterToken(
              id: 'source:${session.sourceContext.source}',
              type: FilterType.source,
              label: session.sourceContext.source,
              value: session.sourceContext.source),
          sortField: SortField.source,
        ),

        // Branch
        if (session.sourceContext.githubRepoContext?.startingBranch != null)
          _buildChip(
            context,
            label: session.sourceContext.githubRepoContext!.startingBranch,
            avatar: const Icon(Icons.call_split, size: 16),
            filterToken: FilterToken(
                id: 'text:${session.sourceContext.githubRepoContext!.startingBranch}',
                type: FilterType.text,
                label: session.sourceContext.githubRepoContext!.startingBranch,
                value: session.sourceContext.githubRepoContext!.startingBranch),
          ),
      ],
    );
  }

  Color _getColorForState(SessionState state) {
    if (state == SessionState.COMPLETED) return Colors.green.shade50;
    if (state == SessionState.FAILED) return Colors.red.shade50;
    if (state == SessionState.IN_PROGRESS || state == SessionState.PLANNING)
      return Colors.blue.shade50;
    return Colors.grey.shade50;
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    Color? backgroundColor,
    Widget? avatar,
    FilterToken? filterToken,
    SortField? sortField,
  }) {
    Widget chip = Chip(
      label: Text(label, style: compact ? const TextStyle(fontSize: 10) : null),
      backgroundColor: backgroundColor,
      avatar: avatar,
      side: BorderSide.none,
      padding: compact ? const EdgeInsets.all(0) : null,
      visualDensity: compact ? VisualDensity.compact : null,
    );

    if (filterToken == null && sortField == null) return chip;

    return GestureDetector(
      onSecondaryTapUp: (details) {
        if (onAddFilter == null && onAddSort == null) return;

        final RenderBox overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final RelativeRect position = RelativeRect.fromRect(
          Rect.fromPoints(details.globalPosition, details.globalPosition),
          Offset.zero & overlay.size,
        );

        showMenu(context: context, position: position, items: <PopupMenuEntry>[
          if (filterToken != null) ...[
            PopupMenuItem(
              child: Row(children: [
                const Icon(Icons.filter_alt, size: 16),
                const SizedBox(width: 8),
                Text("Filter '${filterToken.label}'")
              ]),
              onTap: () => onAddFilter?.call(FilterToken(
                  id: filterToken.id,
                  type: filterToken.type,
                  label: filterToken.label,
                  value: filterToken.value,
                  mode: FilterMode.include)),
            ),
            PopupMenuItem(
              child: Row(children: [
                const Icon(Icons.filter_alt_off, size: 16),
                const SizedBox(width: 8),
                Text("Exclude '${filterToken.label}'")
              ]),
              onTap: () => onAddFilter?.call(FilterToken(
                  id: filterToken.id,
                  type: filterToken.type,
                  label: filterToken.label,
                  value: filterToken.value,
                  mode: FilterMode.exclude)),
            ),
          ],
          if (sortField != null) ...[
            if (filterToken != null) const PopupMenuDivider(),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.arrow_upward, size: 16),
                SizedBox(width: 8),
                Text("Sort Ascending")
              ]),
              onTap: () => onAddSort
                  ?.call(SortOption(sortField, SortDirection.ascending)),
            ),
            PopupMenuItem(
              child: const Row(children: [
                Icon(Icons.arrow_downward, size: 16),
                SizedBox(width: 8),
                Text("Sort Descending")
              ]),
              onTap: () => onAddSort
                  ?.call(SortOption(sortField, SortDirection.descending)),
            ),
          ]
        ]);
      },
      child: chip,
    );
  }
}
