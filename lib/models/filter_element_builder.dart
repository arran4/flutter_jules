import 'filter_element.dart';
import 'search_filter.dart';

/// Builder class for intelligently constructing filter trees
class FilterElementBuilder {
  /// Adds a new filter element to the tree using smart nesting rules
  static FilterElement? addFilter(
      FilterElement? root, FilterElement newElement) {
    // Case 1: Empty root - just return the new element
    if (root == null) {
      return newElement;
    }

    // Case 2: Root is a text element and new is also text - group them with OR
    if (root is TextElement && newElement is TextElement) {
       return OrElement([root, newElement]);
    }

    // Case 3: Same type elements (both labels, both statuses, etc.) - use OR
    if (_isSameFilterType(root, newElement)) {
      // If root is already an OR of this type, add to it
      if (root is OrElement) {
        return OrElement([...root.children, newElement]);
      }
      // Otherwise create new OR
      return OrElement([root, newElement]);
    }

    // Case 3.5: Root is OR and new element matches the OR's type
    if (root is OrElement && root.children.isNotEmpty) {
      if (_isSameFilterType(root.children.first, newElement)) {
        return OrElement([...root.children, newElement]);
      }
    }

    // Case 4: Root is AND - need to check if we can merge with existing OR group
    if (root is AndElement) {
      return _addToAndElement(root, newElement);
    }

    // Case 5: Different types - wrap in AND
    return AndElement([root, newElement]);
  }

  /// Remove a filter element from the tree
  static FilterElement? removeFilter(
    FilterElement? root,
    FilterElement target,
  ) {
    if (root == null) return null;

    // Direct match
    if (_elementsEqual(root, target)) {
      return null;
    }

    // Check composite elements
    if (root is AndElement) {
      return _removeFromComposite(
          root, target, (children) => AndElement(children));
    } else if (root is OrElement) {
      return _removeFromComposite(
          root, target, (children) => OrElement(children));
    } else if (root is NotElement) {
      if (_elementsEqual(root.child, target)) {
        return null;
      }
      final newChild = removeFilter(root.child, target);
      return newChild != null ? NotElement(newChild) : null;
    }

    return root;
  }

  /// Toggle NOT wrapper on an element
  static FilterElement? toggleNot(FilterElement? root, FilterElement target) {
    if (root == null) return null;

    // Direct match
    if (_elementsEqual(root, target)) {
      return NotElement(root);
    }

    // If root is NOT and child matches, unwrap
    if (root is NotElement && _elementsEqual(root.child, target)) {
      return root.child;
    }

    // Check composite elements
    if (root is AndElement) {
      return _transformInComposite(
        root,
        target,
        (children) => AndElement(children),
      );
    } else if (root is OrElement) {
      return _transformInComposite(
        root,
        target,
        (children) => OrElement(children),
      );
    } else if (root is NotElement) {
      final transformed = toggleNot(root.child, target);
      return transformed != null ? NotElement(transformed) : null;
    }

    return root;
  }

  /// Simplifies the tree by removing unnecessary nesting
  static FilterElement? simplify(FilterElement? root) {
    if (root == null) return null;

    if (root is AndElement || root is OrElement) {
      final children =
          root is AndElement ? root.children : (root as OrElement).children;

      // Simplify all children first
      final simplifiedChildren =
          children.map((c) => simplify(c)).whereType<FilterElement>().toList();

      if (simplifiedChildren.isEmpty) return null;
      if (simplifiedChildren.length == 1) return simplifiedChildren.first;

      return root is AndElement
          ? AndElement(simplifiedChildren)
          : OrElement(simplifiedChildren);
    } else if (root is NotElement) {
      final simplified = simplify(root.child);
      return simplified != null ? NotElement(simplified) : null;
    }

    return root;
  }

  // Helper methods

  static bool _isSameFilterType(FilterElement a, FilterElement b) {
    // Text elements can be grouped with OR
    if (a is TextElement && b is TextElement) return true;

    // Statuses are grouped (e.g. Planning OR In Progress)
    if (a is StatusElement && b is StatusElement) return true;

    // PR Statuses are grouped
    if (a is PrStatusElement && b is PrStatusElement) return true;

    // Sources are grouped
    if (a is SourceElement && b is SourceElement) return true;

    // Labels need specific grouping logic
    if (a is LabelElement && b is LabelElement) {
      // "Isolated" labels that should be AND'd
      if (_isIsolatedLabel(a) || _isIsolatedLabel(b)) {
        return false;
      }
      // Otherwise regular labels (New, Updated, Unread, regular tags) are grouped
      return true;
    }

    return false;
  }

  static bool _isIsolatedLabel(LabelElement l) {
    // Watching is isolated
    if (l.value == 'watched') return true;
    
    // Draft is isolated (per user request)
    if (l.value == 'draft') return true;

    // User examples: "Updated, New, Unread" -> Group.
    // "Watching" -> Isolated.
    return false;
  }

  static bool _elementsEqual(FilterElement a, FilterElement b) {
    if (a.runtimeType != b.runtimeType) return false;

    if (a is TextElement && b is TextElement) {
      return a.text == b.text;
    } else if (a is LabelElement && b is LabelElement) {
      return a.value == b.value;
    } else if (a is StatusElement && b is StatusElement) {
      return a.value == b.value;
    } else if (a is SourceElement && b is SourceElement) {
      return a.value == b.value;
    } else if (a is HasPrElement && b is HasPrElement) {
      return true;
    } else if (a is PrStatusElement && b is PrStatusElement) {
      return a.value == b.value;
    }

    return false;
  }

  static FilterElement _addToAndElement(
      AndElement root, FilterElement newElement) {
    // ... existing implementation 
    // Wait, I should probably copy the existing implementation to be safe since I'm targeting a large block or keep it separate?
    // I can just include _addToAndElement as is if I target around it or reuse the logic.
    // For simplicity, I'll just skip modifying _addToAndElement if I don't need to change it, 
    // but the regex replace might be tricky if I don't include enough context. 
    // Actually, I can target specific method bodies if I break it into chunks.
    // But let's try to fit _isSameFilterType + _elementsEqual in one chunk.
    // And fromFilterTokens + _collectTokens in another.
    // This tool call handles _isSameFilterType and _elementsEqual.
    return _addToAndElementInternal(root, newElement);
  }

  static FilterElement _addToAndElementInternal(AndElement root, FilterElement newElement) {
    // Find if there's an OR group of the same type
    final sameTypeOrIndex = root.children.indexWhere((c) {
      if (c is OrElement && c.children.isNotEmpty) {
        return _isSameFilterType(c.children.first, newElement);
      }
      return _isSameFilterType(c, newElement);
    });

    if (sameTypeOrIndex != -1) {
      final child = root.children[sameTypeOrIndex];
      final updatedChildren = [...root.children];

      if (child is OrElement) {
        // Add to existing OR
        updatedChildren[sameTypeOrIndex] =
            OrElement([...child.children, newElement]);
      } else {
        // Convert single element to OR
        updatedChildren[sameTypeOrIndex] = OrElement([child, newElement]);
      }

      return AndElement(updatedChildren);
    } else {
      // Add as new child
      return AndElement([...root.children, newElement]);
    }
  }

  static FilterElement? _removeFromComposite(
    dynamic composite,
    FilterElement target,
    FilterElement Function(List<FilterElement>) constructor,
  ) {
    // ... existing implementation ...
    final children = composite is AndElement
        ? composite.children
        : (composite as OrElement).children;

    final newChildren = <FilterElement>[];
    bool found = false;

    for (final child in children) {
      if (_elementsEqual(child, target)) {
        found = true;
        continue; // Skip this child
      }

      final transformed = removeFilter(child, target);
      if (transformed != null) {
        newChildren.add(transformed);
        if (transformed != child) found = true;
      }
    }

    if (!found) return composite as FilterElement;

    if (newChildren.isEmpty) return null;
    if (newChildren.length == 1) return newChildren.first;

    return constructor(newChildren);
  }

  static FilterElement _transformInComposite(
    dynamic composite,
    FilterElement target,
    FilterElement Function(List<FilterElement>) constructor,
  ) {
    // ... existing implementation ...
    final children = composite is AndElement
        ? composite.children
        : (composite as OrElement).children;

    final newChildren = children.map((child) {
      if (_elementsEqual(child, target)) {
        return NotElement(child);
      }
      return toggleNot(child, target) ?? child;
    }).toList();

    return constructor(newChildren);
  }

  /// Migrate from old FilterToken list to new FilterElement tree
  static FilterElement? fromFilterTokens(List<FilterToken> tokens) {
    if (tokens.isEmpty) return null;

    FilterElement? root;

    for (final token in tokens) {
      FilterElement element;

      // Convert token to appropriate element type
      switch (token.type) {
        case FilterType.flag:
          // Special handling for has_pr
          if (token.value.toString() == 'has_pr' || token.id == 'flag:has_pr') {
            element = HasPrElement();
          } else {
            element = LabelElement(token.label, token.value.toString());
          }
          break;
        case FilterType.status:
          element = StatusElement(token.label, token.value.toString());
          break;
        case FilterType.source:
          element = SourceElement(token.label, token.value.toString());
          break;
        case FilterType.text:
          if (token.id.startsWith('prStatus:')) {
            element = PrStatusElement(token.label, token.value.toString());
          } else {
            element = TextElement(token.value.toString());
          }
          break;
      }

      // Handle exclude mode with NOT wrapper
      if (token.mode == FilterMode.exclude) {
        element = NotElement(element);
      }

      root = addFilter(root, element);
    }

    return simplify(root);
  }

  /// Convert FilterElement tree back to FilterToken list for backward compatibility
  static List<FilterToken> toFilterTokens(FilterElement? root) {
    if (root == null) return [];

    final tokens = <FilterToken>[];
    _collectTokens(root, tokens, FilterMode.include);
    return tokens;
  }

  static void _collectTokens(
    FilterElement element,
    List<FilterToken> tokens,
    FilterMode mode,
  ) {
    if (element is NotElement) {
      _collectTokens(element.child, tokens, FilterMode.exclude);
    } else if (element is AndElement || element is OrElement) {
      final children = element is AndElement
          ? element.children
          : (element as OrElement).children;
      for (final child in children) {
        _collectTokens(child, tokens, mode);
      }
    } else if (element is TextElement) {
      // Text elements don't map to tokens in the old system normally, 
      // but standard texts might not be tokens.
    } else if (element is LabelElement) {
      tokens.add(FilterToken(
        id: 'flag:${element.value}',
        type: FilterType.flag,
        label: element.label,
        value: element.value,
        mode: mode,
      ));
    } else if (element is StatusElement) {
      tokens.add(FilterToken(
        id: 'status:${element.value}',
        type: FilterType.status,
        label: element.label,
        value: element.value,
        mode: mode,
      ));
    } else if (element is SourceElement) {
      tokens.add(FilterToken(
        id: 'source:${element.value}',
        type: FilterType.source,
        label: element.label,
        value: element.value,
        mode: mode,
      ));
    } else if (element is HasPrElement) {
      tokens.add(FilterToken(
        id: 'flag:has_pr',
        type: FilterType.flag,
        label: 'Has PR',
        value: 'has_pr',
        mode: mode,
      ));
    } else if (element is PrStatusElement) {
      tokens.add(FilterToken(
        id: 'prStatus:${element.value}',
        type: FilterType.text,
        label: element.label,
        value: element.value,
        mode: mode,
      ));
    }
  }
}
