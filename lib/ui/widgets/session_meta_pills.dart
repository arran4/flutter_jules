import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models.dart';
import 'note_dialog.dart';

class _PillDefinition {
  final bool Function(Session) shouldShow;
  final List<Widget> Function(BuildContext, SessionMetaPills) build;

  _PillDefinition({required this.shouldShow, required this.build});
}

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

  static final List<_PillDefinition> _pillDefinitions = [
    // STATE Pill
    _PillDefinition(
      shouldShow: (s) => s.state != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: widget.session.state!.displayName,
          backgroundColor: widget._getColorForState(widget.session.state!),
          avatar: widget.session.state == SessionState.COMPLETED
              ? const Icon(Icons.check, size: 16, color: Colors.green)
              : null,
          filterToken: FilterToken(
            id: 'status:${widget.session.state!.name}',
            type: FilterType.status,
            label: widget.session.state!.displayName,
            value: widget.session.state!,
          ),
          sortField: SortField.status,
        ),
      ],
    ),
    // DATE Pill (Created)
    _PillDefinition(
      shouldShow: (s) => s.createTime != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: DateFormat.yMMMd().add_jm().format(
                DateTime.parse(widget.session.createTime!).toLocal(),
              ),
          sortField: SortField.created,
        ),
      ],
    ),
    // DATE Pill (Updated)
    _PillDefinition(
      shouldShow: (s) => s.updateTime != null && s.createTime != s.updateTime,
      build: (context, widget) => [
        widget._buildChip(
          context,
          avatar: const Icon(Icons.update, size: 16),
          label:
              "Updated ${DateFormat.yMMMd().add_jm().format(DateTime.parse(widget.session.updateTime!).toLocal())}",
          sortField: SortField.updated,
        ),
      ],
    ),
    // Automation Mode
    _PillDefinition(
      shouldShow: (s) =>
          s.automationMode != null &&
          s.automationMode != AutomationMode.AUTOMATION_MODE_UNSPECIFIED,
      build: (context, widget) => [
        widget._buildChip(
          context,
          avatar: const Icon(Icons.smart_toy, size: 16),
          label:
              "Auto: ${widget.session.automationMode.toString().split('.').last.replaceAll('AUTOMATION_MODE_', '')}",
          backgroundColor: Colors.blue.shade50,
        ),
      ],
    ),
    // Approval
    _PillDefinition(
      shouldShow: (s) => s.requirePlanApproval != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: widget.session.requirePlanApproval!
              ? "Approval Required"
              : "No Approval Required",
          avatar: Icon(
            widget.session.requirePlanApproval!
                ? Icons.check_circle_outline
                : Icons.do_not_disturb_on_outlined,
            size: 16,
          ),
          backgroundColor: widget.session.requirePlanApproval!
              ? Colors.orange.shade50
              : Colors.green.shade50,
          filterToken: FilterToken(
            id: 'flag:approval',
            type: FilterType.flag,
            label: widget.session.requirePlanApproval!
                ? 'Approval Required'
                : 'No Approval',
            value: widget.session.requirePlanApproval!
                ? 'approval_required'
                : 'no_approval',
          ),
        ),
      ],
    ),
    // PR Status
    _PillDefinition(
      shouldShow: (s) => s.prStatus != null,
      build: (context, widget) =>
          widget._buildPrStatusChips(context, widget.session.prStatus!),
    ),
    // Publish PR Chip
    _PillDefinition(
      shouldShow: (s) => s.prStatus == null && s.diffUrl != null,
      build: (context, widget) => [widget._buildPublishPrChip(context)],
    ),
    // CI Status
    _PillDefinition(
      shouldShow: (s) => s.ciStatus != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: 'CI: ${widget.session.ciStatus}',
          avatar: Icon(
            widget.session.ciStatus == 'Success'
                ? Icons.check_circle
                : (widget.session.ciStatus == 'Failure'
                    ? Icons.cancel
                    : Icons.pending),
            size: 16,
          ),
          backgroundColor: widget.session.ciStatus == 'Success'
              ? Colors.green.shade50
              : (widget.session.ciStatus == 'Failure'
                  ? Colors.red.shade50
                  : Colors.amber.shade50),
          filterToken: FilterToken(
            id: 'ciStatus:${widget.session.ciStatus}',
            type: FilterType.ciStatus,
            label: 'CI: ${widget.session.ciStatus}',
            value: widget.session.ciStatus!,
          ),
        ),
      ],
    ),
    // Source
    _PillDefinition(
      shouldShow: (s) => s.sourceContext != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: widget.session.sourceContext!.source,
          avatar: const Icon(Icons.source, size: 16),
          filterToken: FilterToken(
            id: 'source:${widget.session.sourceContext!.source}',
            type: FilterType.source,
            label: widget.session.sourceContext!.source,
            value: widget.session.sourceContext!.source,
          ),
          sortField: SortField.source,
        ),
      ],
    ),
    // Branch
    _PillDefinition(
      shouldShow: (s) =>
          s.sourceContext?.githubRepoContext?.startingBranch != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: widget.session.sourceContext!.githubRepoContext!.startingBranch,
          avatar: const Icon(Icons.call_split, size: 16),
          filterToken: FilterToken(
            id:
                'branch:${widget.session.sourceContext!.githubRepoContext!.startingBranch}',
            type: FilterType.branch,
            label:
                widget.session.sourceContext!.githubRepoContext!.startingBranch,
            value:
                widget.session.sourceContext!.githubRepoContext!.startingBranch,
          ),
        ),
      ],
    ),
    // Mergeable State
    _PillDefinition(
      shouldShow: (s) => s.mergeableState != null && s.mergeableState != 'unknown',
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: 'Mergeable: ${widget.session.mergeableState}',
          backgroundColor: widget._getColorForMergeableState(
            widget.session.mergeableState!,
          ),
        ),
      ],
    ),
    // File Changes
    _PillDefinition(
      shouldShow: (s) =>
          s.additions != null && s.deletions != null && s.changedFiles != null,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label:
              '+${widget.session.additions} -${widget.session.deletions} (${widget.session.changedFiles} files)',
          avatar: const Icon(Icons.edit_document, size: 16),
          backgroundColor: Colors.grey.shade200,
        ),
      ],
    ),
    // Tags
    _PillDefinition(
      shouldShow: (s) => s.tags != null && s.tags!.isNotEmpty,
      build: (context, widget) => widget.session.tags!
          .map(
            (tag) => widget._buildChip(
              context,
              label: '#$tag',
              avatar: const Icon(Icons.tag, size: 16),
              backgroundColor: Colors.indigo.shade50,
              filterToken: FilterToken(
                id: 'tag:$tag',
                type: FilterType.tag,
                label: '#$tag',
                value: tag,
              ),
            ),
          )
          .toList(),
    ),
    // Note
    _PillDefinition(
      shouldShow: (s) => s.note?.content.isNotEmpty ?? false,
      build: (context, widget) => [
        widget._buildChip(
          context,
          label: 'Note',
          avatar: const Icon(Icons.note, size: 16),
          tooltip: widget.session.note!.content,
          filterToken: const FilterToken(
            id: 'flag:has_notes',
            type: FilterType.flag,
            label: 'Has Notes',
            value: 'has_notes',
          ),
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = _pillDefinitions
        .where((def) => def.shouldShow(session))
        .expand((def) => def.build(context, this))
        .toList();

    return Wrap(
      spacing: compact ? 4.0 : 8.0,
      runSpacing: compact ? 2.0 : 4.0,
      children: children,
    );
  }

  Widget _buildPublishPrChip(BuildContext context) {
    return InkWell(
      onTap: () {
        if (session.url != null) {
          launchUrl(Uri.parse(session.url!));
        }
      },
      child: Chip(
        label: const Text(
          "Goto Jules and click Publish PR",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.purple,
        avatar: const Icon(Icons.publish, size: 16, color: Colors.white),
        side: BorderSide.none,
        padding: compact ? const EdgeInsets.all(0) : null,
        visualDensity: compact ? VisualDensity.compact : null,
      ),
    );
  }

  List<Widget> _buildPrStatusChips(BuildContext context, String prStatus) {
    final chips = <Widget>[];
    IconData icon;
    Color color;

    switch (prStatus) {
      case 'Open':
        icon = Icons.code; // Or any other appropriate icon
        color = Colors.blue.shade50;
        break;
      case 'Draft':
        icon = Icons.edit_note;
        color = Colors.amber.shade50;
        break;
      case 'Merged':
        icon = Icons.merge_type;
        color = Colors.purple.shade50;
        break;
      case 'Closed':
        icon = Icons.highlight_off;
        color = Colors.red.shade50;
        break;
      default:
        // Optional: handle unknown status
        return [];
    }

    chips.add(
      _buildChip(
        context,
        label: 'PR: $prStatus',
        avatar: Icon(icon, size: 16),
        backgroundColor: color,
        filterToken: FilterToken(
          id: 'prStatus:$prStatus',
          type: FilterType.prStatus,
          label: 'PR: $prStatus',
          value: prStatus,
        ),
      ),
    );
    return chips;
  }

  Color _getColorForMergeableState(String state) {
    switch (state.toLowerCase()) {
      case 'clean':
        return Colors.green.shade100;
      case 'dirty':
      case 'unstable':
        return Colors.red.shade100;
      case 'blocked':
        return Colors.orange.shade100;
      default: // unknown, etc.
        return Colors.grey.shade200;
    }
  }

  Color _getColorForState(SessionState state) {
    if (state == SessionState.COMPLETED) return Colors.green.shade50;
    if (state == SessionState.FAILED) return Colors.red.shade50;
    if (state == SessionState.IN_PROGRESS || state == SessionState.PLANNING) {
      return Colors.blue.shade50;
    }
    return Colors.grey.shade50;
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    Color? backgroundColor,
    Widget? avatar,
    FilterToken? filterToken,
    SortField? sortField,
    String? tooltip,
  }) {
    Widget chip = Chip(
      label: Text(label, style: compact ? const TextStyle(fontSize: 10) : null),
      backgroundColor: backgroundColor,
      avatar: avatar,
      side: BorderSide.none,
      padding: compact ? const EdgeInsets.all(0) : null,
      visualDensity: compact ? VisualDensity.compact : null,
    );

    if (tooltip != null) {
      chip = Tooltip(message: tooltip, child: chip);
    }

    if (filterToken != null) {
      chip = Draggable<FilterToken>(
        data: filterToken,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.8, child: chip),
        ),
        childWhenDragging: chip,
        child: chip,
      );
    }

    if (filterToken == null && sortField == null) return chip;

    void showChipMenu(Offset globalPosition) {
      if (onAddFilter == null && onAddSort == null) return;

      final RenderBox overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox;
      final RelativeRect position = RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      );

      showMenu(
        context: context,
        position: position,
        items: <PopupMenuEntry>[
          if (filterToken != null) ...[
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Filter '${filterToken.label}'",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: () => onAddFilter?.call(
                FilterToken(
                  id: filterToken.id,
                  type: filterToken.type,
                  label: filterToken.label,
                  value: filterToken.value,
                  mode: FilterMode.include,
                ),
              ),
            ),
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_off, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Exclude '${filterToken.label}'",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              onTap: () => onAddFilter?.call(
                FilterToken(
                  id: filterToken.id,
                  type: filterToken.type,
                  label: filterToken.label,
                  value: filterToken.value,
                  mode: FilterMode.exclude,
                ),
              ),
            ),
          ],
          if (sortField != null) ...[
            if (filterToken != null) const PopupMenuDivider(),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.arrow_upward, size: 16),
                  SizedBox(width: 8),
                  Text("Sort Ascending"),
                ],
              ),
              onTap: () => onAddSort?.call(
                SortOption(sortField, SortDirection.ascending),
              ),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.arrow_downward, size: 16),
                  SizedBox(width: 8),
                  Text("Sort Descending"),
                ],
              ),
              onTap: () => onAddSort?.call(
                SortOption(sortField, SortDirection.descending),
              ),
            ),
          ],
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (details) => showChipMenu(details.globalPosition),
      child: chip,
    );
  }
}
