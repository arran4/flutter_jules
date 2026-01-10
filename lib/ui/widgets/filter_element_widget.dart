import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/filter_element.dart';

enum FilterDropAction { groupOr, groupAnd, addToGroup, groupAboveAnd, groupAboveOr }

/// Widget that renders a FilterElement tree as nested pills
class FilterElementWidget extends StatelessWidget {
  final FilterElement? element;
  final Function(FilterElement)? onRemove;
  final Function(FilterElement)? onToggleNot;
  final Function(FilterElement)? onTap;
  final Function(FilterElement source, FilterElement target, FilterDropAction action, bool isCopy)? onDrop;

  const FilterElementWidget({
    super.key,
    required this.element,
    this.onRemove,
    this.onToggleNot,
    this.onTap,
    this.onDrop,
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
      onWillAcceptWithDetails: (details) => details.data != element, // Prevent self-drop
      onAcceptWithDetails: (details) => _handleDrop(context, details.data, element),
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHovered ? Colors.blueAccent : textColor.withValues(alpha: 0.3),
              width: isHovered ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isHovered ? Colors.blue.withValues(alpha: 0.1) : backgroundColor.withValues(alpha: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with operator label
              InkWell(
                onTap: onTap != null ? () => onTap!(element) : null,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              // Children
              Padding(
                padding:
                    const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: children.map((child) {
                    return FilterElementWidget(
                      element: child,
                      onRemove: onRemove,
                      onToggleNot: onToggleNot,
                      onTap: onTap,
                      onDrop: onDrop,
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
          // Child
          Padding(
            padding:
                const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
            child: FilterElementWidget(
              element: element.child,
              onRemove: onRemove,
              onToggleNot: onToggleNot,
              onTap: onTap,
              onDrop: onDrop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeafVisual(
    BuildContext context,
    FilterElement element,
    String label,
    Color backgroundColor,
    Color textColor,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap != null ? () => onTap!(element) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onRemove!(element),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: textColor.withValues(alpha: 0.7),
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
        context, element, label, backgroundColor, textColor, icon);

    // Wrap in DragTarget to accept drops
    Widget child = DragTarget<FilterElement>(
      onWillAcceptWithDetails: (details) => details.data != element,
      onAcceptWithDetails: (details) => _handleDrop(context, details.data, element),
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
              context, element, label, backgroundColor, textColor, icon),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: child),
      child: child,
    );
  }

  void _handleDrop(
      BuildContext context, FilterElement source, FilterElement target) async {
    if (onDrop == null) return;

    final isCtrlPressed = ServicesBinding.instance.keyboard.logicalKeysPressed
        .contains(LogicalKeyboardKey.controlLeft) ||
        ServicesBinding.instance.keyboard.logicalKeysPressed
        .contains(LogicalKeyboardKey.controlRight);

    // Show Popup Menu
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    
    final List<PopupMenuEntry<FilterDropAction>> items = [];

    if (target is AndElement || target is OrElement) {
        items.add(const PopupMenuItem(
          value: FilterDropAction.addToGroup,
          child: Text("Add to Group"),
        ));
        
        // Show option to create Opposing group above
        final oppositeLabel = target is AndElement ? "OR" : "AND";
        final action = target is AndElement ? FilterDropAction.groupAboveOr : FilterDropAction.groupAboveAnd;
        
        items.add(PopupMenuItem(
          value: action,
          child: Text("Create $oppositeLabel Group Above"),
        ));
    } else {
        // Leaf target
        items.add(const PopupMenuItem(
          value: FilterDropAction.groupOr,
          child: Text("Group with OR"),
        ));
        items.add(const PopupMenuItem(
          value: FilterDropAction.groupAnd,
          child: Text("Group with AND"),
        ));
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
