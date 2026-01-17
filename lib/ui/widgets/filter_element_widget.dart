import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/filter_element.dart';
import '../../models/time_filter.dart';
import '../../utils/filter_utils.dart';

enum FilterDropAction {
  groupOr,
  groupAnd,
  addToGroup,
  groupAboveAnd,
  groupAboveOr,
}

/// Widget that renders a FilterElement tree as nested pills
class FilterElementWidget extends StatelessWidget {
  final FilterElement? element;
  final Function(FilterElement)? onRemove;
  final Function(FilterElement)? onToggleNot;
  final Function(FilterElement)? onToggleEnabled;
  final Function(FilterElement)? onTap;
  final Function(
    FilterElement source,
    FilterElement target,
    FilterDropAction action,
    bool isCopy,
  )? onDrop;
  final Function(FilterElement target, FilterElement alternative)?
      onAddAlternative;
  final bool isNegated;
  final bool isParentDisabled;

  const FilterElementWidget({
    super.key,
    required this.element,
    this.onRemove,
    this.onToggleNot,
    this.onToggleEnabled,
    this.onTap,
    this.onDrop,
    this.onAddAlternative,
    this.isNegated = false,
    this.isParentDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (element == null) {
      return const SizedBox.shrink();
    }

    return _buildElement(context, element!);
  }

  Widget _buildElement(BuildContext context, FilterElement element) {
    if (element is AndElement) {
      return _buildCompositeElement(
        context,
        element,
        'AND',
        Colors.blue.shade100,
        Colors.blue.shade700,
        Icons.merge_type,
      );
    } else if (element is OrElement) {
      return _buildCompositeElement(
        context,
        element,
        'OR',
        Colors.purple.shade100,
        Colors.purple.shade700,
        Icons.call_split,
      );
    } else if (element is NotElement) {
      return _buildNotElement(context, element);
    } else if (element is TextElement) {
      return _buildLeafElement(
        context,
        element,
        element.text,
        Colors.grey.shade200,
        Colors.grey.shade800,
        Icons.text_fields,
      );
    } else if (element is LabelElement) {
      return _buildLeafElement(
        context,
        element,
        element.label,
        Colors.green.shade100,
        Colors.green.shade800,
        Icons.flag,
      );
    } else if (element is StatusElement) {
      return _buildLeafElement(
        context,
        element,
        element.label,
        Colors.blue.shade100,
        Colors.blue.shade800,
        Icons.info_outline,
      );
    } else if (element is SourceElement) {
      return _buildLeafElement(
        context,
        element,
        element.label,
        Colors.purple.shade100,
        Colors.purple.shade800,
        Icons.source,
      );
    } else if (element is HasPrElement) {
      return _buildLeafElement(
        context,
        element,
        'Has PR',
        Colors.orange.shade100,
        Colors.orange.shade800,
        Icons.merge,
      );
    } else if (element is PrStatusElement) {
      final label = element.label;
      final displayLabel =
          label.toUpperCase().startsWith('PR:') ? label : 'PR: $label';
      return _buildLeafElement(
        context,
        element,
        displayLabel,
        Colors.teal.shade100,
        Colors.teal.shade800,
        Icons.merge_type,
      );
    } else if (element is BranchElement) {
      final label = element.label;
      final displayLabel =
          label.startsWith('Branch:') ? label : 'Branch: $label';
      return _buildLeafElement(
        context,
        element,
        displayLabel,
        Colors.indigo.shade100,
        Colors.indigo.shade800,
        Icons.account_tree,
      );
    } else if (element is CiStatusElement) {
      final label = element.label;
      final displayLabel =
          label.toUpperCase().startsWith('CI:') ? label : 'CI: $label';
      return _buildLeafElement(
        context,
        element,
        displayLabel,
        Colors.blueGrey.shade100,
        Colors.blueGrey.shade800,
        Icons.check_circle_outline,
      );
    } else if (element is TimeFilterElement) {
      final label = _formatTimeFilter(element.timeFilter);
      return _buildLeafElement(
        context,
        element,
        label,
        Colors.brown.shade100,
        Colors.brown.shade800,
        Icons.access_time,
      );
    } else if (element is NoSourceElement) {
      return _buildLeafElement(
        context,
        element,
        'Has No Source',
        Colors.red.shade100,
        Colors.red.shade800,
        Icons.cloud_off,
      );
    } else if (element is TagElement) {
      return _buildLeafElement(
        context,
        element,
        '#${element.label}', // Assuming text/label is the tag name. Check FilterElement definition.
        Colors.indigo.shade100,
        Colors.indigo.shade800,
        Icons.tag,
      );
    } else if (element is HasNotesElement) {
      return _buildLeafElement(
        context,
        element,
        'Has Notes',
        Colors.amber.shade100,
        Colors.amber.shade900,
        Icons.note,
      );
    } else if (element is DisabledElement) {
      return _buildDisabledElement(context, element);
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompositeElement(
    BuildContext context,
    dynamic element,
    String label,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    final children = element is AndElement
        ? element.children
        : (element as OrElement).children;

    return DragTarget<FilterElement>(
      onWillAcceptWithDetails: (details) =>
          details.data != element, // Prevent self-drop
      onAcceptWithDetails: (details) =>
          _handleDrop(context, details.data, element),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHovered
                  ? Colors.blueAccent
                  : textColor.withValues(alpha: 0.3),
              width: isHovered ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isHovered
                ? Colors.blue.withValues(alpha: 0.1)
                : backgroundColor.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with operator label
              GestureDetector(
                onSecondaryTapUp: (details) =>
                    _showContextMenu(context, details, element),
                child: InkWell(
                  onTap: onTap != null ? () => onTap!(element) : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        topRight: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: textColor),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Children
              Padding(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 4,
                  top: 4,
                  bottom: 4,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: children.map((child) {
                    return FilterElementWidget(
                      element: child,
                      onRemove: onRemove,
                      onToggleNot: onToggleNot,
                      onToggleEnabled: onToggleEnabled,
                      onTap: onTap,
                      onDrop: onDrop,
                      onAddAlternative: onAddAlternative,
                      // Children of composite are not negated by the composite itself
                      isNegated: false,
                      isParentDisabled: isParentDisabled,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotElement(BuildContext context, NotElement element) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: Colors.red.shade50.withValues(alpha: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // NOT header
          InkWell(
            onTap: onTap != null ? () => onTap!(element) : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: GestureDetector(
                onSecondaryTapUp: (details) =>
                    _showContextMenu(context, details, element),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 14, color: Colors.red.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'NOT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    if (onToggleNot != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => onToggleNot!(element),
                        child: Icon(
                          Icons.undo,
                          size: 14,
                          color: Colors.red.shade700.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Child
          Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            child: FilterElementWidget(
              element: element.child,
              onRemove: onRemove,
              onToggleNot: onToggleNot,
              onToggleEnabled: onToggleEnabled,
              onTap: onTap,
              onDrop: onDrop,
              onAddAlternative: onAddAlternative,
              isNegated: true,
              isParentDisabled: isParentDisabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledElement(BuildContext context, DisabledElement element) {
    final bgColor = Colors.grey.shade100.withValues(alpha: 0.5);
    final borderColor = Colors.grey.shade300;
    final headerColor = Colors.grey.shade200;
    final headerTextColor = Colors.grey.shade500;
    final headerIconColor = Colors.grey.shade500;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(8),
        color: bgColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // DISABLED header
          InkWell(
            onTap: onTap != null ? () => onTap!(element) : null,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: GestureDetector(
                onSecondaryTapUp: (details) =>
                    _showContextMenu(context, details, element),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 14,
                      color: headerIconColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DISABLED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: headerTextColor,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    // Allow toggling back to Enabled (handled via context menu mainly, but could add quick action)
                  ],
                ),
              ),
            ),
          ),
          // Child
          Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            child: FilterElementWidget(
              element: element.child,
              onRemove: onRemove,
              onToggleNot: onToggleNot,
              onToggleEnabled: onToggleEnabled,
              onTap: onTap,
              onDrop: onDrop,
              onAddAlternative: onAddAlternative,
              isNegated: isNegated, // Inherit
              isParentDisabled: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    TapUpDetails details,
    FilterElement element,
  ) async {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final alternatives = FilterUtils.getAlternatives(element);

    final items = <PopupMenuEntry<int>>[];

    // 1. Exclude/Include logic
    final isComposite = element is AndElement || element is OrElement;
    final isNot = element is NotElement;
    final isDisabled = element is DisabledElement;

    if (isNot) {
      items.add(
        const PopupMenuItem(
          value: 3, // New value for "Remove NOT"
          enabled: true,
          child: Text("Remove NOT"),
        ),
      );
      items.add(const PopupMenuDivider());
    } else if (!isDisabled) {
      final excludeText = isComposite ? "Exclude this group" : "Exclude this";
      items.add(
        PopupMenuItem(
          value: 1,
          enabled: true,
          child: Text(isNegated ? "Include this" : excludeText),
        ),
      );
      items.add(const PopupMenuDivider());
    }

    // 2. Enabled/Disabled checkbox
    items.add(
      CheckedPopupMenuItem(
        value: 2,
        checked: element is! DisabledElement && !isParentDisabled,
        enabled: !isParentDisabled,
        child: const Text("Enabled"),
      ),
    );

    if (alternatives.isNotEmpty) {
      items.add(const PopupMenuDivider());
      for (int i = 0; i < alternatives.length; i++) {
        final alt = alternatives[i];
        String label = "Add Option";
        if (alt is PrStatusElement) {
          label = "Add PR: ${alt.label}";
        } else if (alt is StatusElement) {
          label = "Add ${alt.label}";
        } else if (alt is LabelElement) {
          label = "Add ${alt.label}";
        } else if (alt is SourceElement) {
          label = "Add Source: ${alt.label}";
        } else if (alt is CiStatusElement) {
          label = "Add CI: ${alt.label}";
        }

        items.add(PopupMenuItem(value: 100 + i, child: Text(label)));
      }
    }

    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: items,
    );

    if (selected == null) return;

    if (selected == 1) {
      // Toggle NOT
      if (onToggleNot != null) {
        onToggleNot!(element);
      }
    } else if (selected == 3) {
      // Remove NOT
      if (onToggleNot != null) {
        onToggleNot!(element);
      }
    } else if (selected == 2) {
      // Toggle Enabled
      if (onToggleEnabled != null) {
        onToggleEnabled!(element);
      }
    } else if (selected >= 100) {
      // Alternative selected
      final altIndex = selected - 100;
      if (altIndex >= 0 && altIndex < alternatives.length) {
        final alt = alternatives[altIndex];
        if (onAddAlternative != null) {
          onAddAlternative!(element, alt);
        }
      }
    }
  }

  Widget _buildLeafVisual(
    BuildContext context,
    FilterElement element,
    String label,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    final bool isActuallyDisabled =
        element is DisabledElement || isParentDisabled;
    final effectiveTextColor =
        isActuallyDisabled ? textColor.withValues(alpha: 0.5) : textColor;
    final effectiveBackgroundColor = isActuallyDisabled
        ? backgroundColor.withValues(alpha: 0.5)
        : backgroundColor;

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details, element),
      onTap: onTap != null ? () => onTap!(element) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: effectiveTextColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: effectiveTextColor,
                fontWeight: FontWeight.w500,
                decoration: isActuallyDisabled
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onRemove!(element),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: effectiveTextColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeafElement(
    BuildContext context,
    FilterElement element,
    String label,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    final leafVisual = _buildLeafVisual(
      context,
      element,
      label,
      backgroundColor,
      textColor,
      icon,
    );

    // Wrap in DragTarget to accept drops
    Widget child = DragTarget<FilterElement>(
      onWillAcceptWithDetails: (details) => details.data != element,
      onAcceptWithDetails: (details) =>
          _handleDrop(context, details.data, element),
      builder: (context, candidateData, rejectedData) {
        if (candidateData.isNotEmpty) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueAccent, width: 2),
            ),
            child: leafVisual,
          );
        }
        return leafVisual;
      },
    );

    // Wrap in Draggable
    return Draggable<FilterElement>(
      data: element,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: _buildLeafVisual(
            context,
            element,
            label,
            backgroundColor,
            textColor,
            icon,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: child),
      child: child,
    );
  }

  String _formatTimeFilter(TimeFilter tf) {
    String field = tf.field.name;
    field = field[0].toUpperCase() + field.substring(1);

    switch (tf.type) {
      case TimeFilterType.newerThan:
        return '$field is newer than ${tf.range ?? tf.specificTime}';
      case TimeFilterType.olderThan:
        return '$field is older than ${tf.range ?? tf.specificTime}';
      case TimeFilterType.between:
      case TimeFilterType.inRange:
        if (tf.specificTime != null && tf.specificTimeEnd != null) {
          final difference = tf.specificTimeEnd!.difference(tf.specificTime!);
          if (difference.inHours <= 24 && tf.specificTime!.day == tf.specificTimeEnd!.subtract(const Duration(seconds: 1)).day) {
            return '$field is on ${DateFormat.yMMMd().format(tf.specificTime!)}';
          }
          return '$field is between ${DateFormat.yMMMd().format(tf.specificTime!)} and ${DateFormat.yMMMd().format(tf.specificTimeEnd!)}';
        }
        if (tf.range != null) {
          return '$field is in ${tf.range}';
        }
    }
    return 'Invalid Time Filter';
  }

  void _handleDrop(
    BuildContext context,
    FilterElement source,
    FilterElement target,
  ) async {
    if (onDrop == null) return;

    final isCtrlPressed =
        ServicesBinding.instance.keyboard.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlLeft,
            ) ||
            ServicesBinding.instance.keyboard.logicalKeysPressed.contains(
              LogicalKeyboardKey.controlRight,
            );

    // Show Popup Menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    final List<PopupMenuEntry<FilterDropAction>> items = [];

    if (target is AndElement || target is OrElement) {
      items.add(
        const PopupMenuItem(
          value: FilterDropAction.addToGroup,
          child: Text("Add to Group"),
        ),
      );

      // Show option to create Opposing group above
      final oppositeLabel = target is AndElement ? "OR" : "AND";
      final action = target is AndElement
          ? FilterDropAction.groupAboveOr
          : FilterDropAction.groupAboveAnd;

      items.add(
        PopupMenuItem(
          value: action,
          child: Text("Create $oppositeLabel above"),
        ),
      );
    } else {
      // Leaf target
      items.add(
        const PopupMenuItem(
          value: FilterDropAction.groupOr,
          child: Text("Group with OR"),
        ),
      );
      items.add(
        const PopupMenuItem(
          value: FilterDropAction.groupAnd,
          child: Text("Group with AND"),
        ),
      );
    }

    final selectedAction = await showMenu<FilterDropAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + renderBox.size.height,
        offset.dx + renderBox.size.width,
        offset.dy + renderBox.size.height,
      ),
      items: items,
    );

    if (selectedAction != null) {
      onDrop!(source, target, selectedAction, isCtrlPressed);
    }
  }
}
