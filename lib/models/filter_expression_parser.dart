import 'filter_element.dart';
import 'time_filter.dart';
import '../utils/time_parser.dart';

class FilterExpressionParser {
  final String input;
  int pos = 0;

  FilterExpressionParser(this.input);

  static FilterElement? parse(String input) {
    if (input.trim().isEmpty) return null;
    return FilterExpressionParser(input)._parseTopLevel();
  }

  FilterElement? _parseTopLevel() {
    _skipWhitespace();
    final elements = <FilterElement>[];
    while (pos < input.length) {
      final e = _parseElement();
      if (e != null) {
        elements.add(e);
      } else {
        // Skip invalid characters
        pos++;
      }
      _skipCommaOrWhitespace();
    }

    if (elements.isEmpty) return null;
    if (elements.length == 1) return elements[0];
    return AndElement(elements);
  }

  FilterElement? _parseElement() {
    _skipWhitespace();
    if (pos < input.length && input[pos] == '#') {
      pos++;
      final args = <String>[];
      if (pos < input.length && input[pos] == '(') {
        pos++;
        final start = pos;
        int depth = 1;
        while (pos < input.length && depth > 0) {
          if (input[pos] == '(') depth++;
          if (input[pos] == ')') depth--;
          if (depth > 0) pos++;
        }
        final content = input.substring(start, pos).trim();
        if (content.isNotEmpty) {
          args.add(_unescape(content));
        }
        if (pos < input.length && input[pos] == ')') {
          pos++;
        }
      } else {
        final ident = _readIdentifier();
        if (ident.isNotEmpty) {
          args.add(ident);
        }
      }
      return _createFilter('HASHTAG', [], args);
    }
    final name = _readIdentifier();
    if (name.isEmpty) return null;

    final children = <FilterElement>[];
    final args = <String>[];

    _skipWhitespace();
    if (pos < input.length && input[pos] == '(') {
      pos++; // skip (
      _skipWhitespace();

      final upperName = name.toUpperCase();
      final isComposite = upperName == 'AND' ||
          upperName == 'OR' ||
          upperName == 'NOT' ||
          upperName == 'DISABLED';

      if (isComposite) {
        while (pos < input.length && input[pos] != ')') {
          final child = _parseElement();
          if (child != null) {
            children.add(child);
          } else {
            // Might be a trailing comma or paren or junk
            if (pos < input.length && input[pos] != ')') pos++;
          }
          _skipCommaOrWhitespace();
        }
      } else {
        // Simple function: everything between ( and matching ) is considered the arg(s).
        // Since we want to support multiple args split by spaces/commas for backward compat
        // OR atoms, let's read until matching ')'.
        final start = pos;
        int depth = 1;
        while (pos < input.length && depth > 0) {
          if (input[pos] == '(') depth++;
          if (input[pos] == ')') depth--;
          if (depth > 0) pos++;
        }
        final content = input.substring(start, pos).trim();
        if (content.isNotEmpty) {
          args.add(_unescape(content));
        }
      }

      if (pos < input.length && input[pos] == ')') {
        pos++; // skip )
      }
    }

    return _createFilter(name, children, args);
  }

  String _unescape(String s) {
    if (s.startsWith('(') && s.endsWith(')')) {
      s = s.substring(1, s.length - 1);
    }
    return s.replaceAll('\\)', ')').replaceAll('\\\\', '\\');
  }

  String _readIdentifier() {
    final start = pos;
    while (
        pos < input.length && RegExp(r'[a-zA-Z0-9_\.]').hasMatch(input[pos])) {
      pos++;
    }
    return input.substring(start, pos);
  }

  void _skipWhitespace() {
    while (pos < input.length && RegExp(r'[\s,]').hasMatch(input[pos])) {
      pos++;
    }
  }

  void _skipCommaOrWhitespace() {
    _skipWhitespace();
  }

  FilterElement? _createFilter(
    String name,
    List<FilterElement> children,
    List<String> args,
  ) {
    final upperName = name.toUpperCase();
    switch (upperName) {
      case 'AND':
        return AndElement(children);
      case 'OR':
        return OrElement(children);
      case 'DISABLED':
        return children.isNotEmpty ? DisabledElement(children[0]) : null;
      case 'NOT':
        return children.isNotEmpty ? NotElement(children[0]) : null;
      case 'TEXT':
      case 'SEARCH':
        return TextElement(args.isNotEmpty ? args[0] : '');
      case 'NEW':
        return LabelElement('New', 'new');
      case 'UPDATED':
        return LabelElement('Updated', 'updated');
      case 'UNREAD':
        return LabelElement('Unread', 'unread');
      case 'HIDDEN':
        return LabelElement('Hidden', 'hidden');
      case 'WATCHING':
      case 'WATCHED':
        return LabelElement('Watching', 'watched');
      case 'PENDING':
        return LabelElement('Pending', 'pending');
      case 'LABEL':
        return args.isNotEmpty ? LabelElement(args[0], args[0]) : null;
      case 'HAS':
        if (args.isEmpty) return null;
        final arg = args[0].toUpperCase();
        if (arg == 'PR') return HasPrElement();
        if (arg == 'NOSOURCE') return NoSourceElement();
        if (arg == 'NOTES') return HasNotesElement();
        if (arg == 'ERRORS' || arg == 'ERROR') return HasErrorsElement();
        if (arg == 'DRAFTS' || arg == 'DRAFT') {
          return LabelElement('Draft', 'draft');
        }
        if (arg == 'CREATEPR' ||
            arg == 'CREATE_PR' ||
            arg == 'PRREADY' ||
            arg == 'PR_READY') {
          return HasCreatePrElement();
        }
        return LabelElement(args[0], args[0]);
      case 'HAS_PR':
        return HasPrElement();
      case 'STATE':
      case 'SESSIONSTATE':
      case 'STATUS':
      case 'JULES_STATE':
      case 'JULESSTATE':
        if (args.isEmpty) return null;
        String val = args[0];
        if (val.startsWith('SessionState.')) val = val.substring(13);
        if (val.startsWith('State.')) val = val.substring(6);
        return StatusElement(val, val);
      case 'SOURCE':
        return args.isNotEmpty ? SourceElement(args[0], args[0]) : null;
      case 'PR':
      case 'PR_STATUS':
        return args.isNotEmpty ? PrStatusElement(args[0], args[0]) : null;
      case 'CI':
      case 'CI_STATUS':
        return args.isNotEmpty ? CiStatusElement(args[0], args[0]) : null;
      case 'BRANCH':
        return args.isNotEmpty ? BranchElement(args[0], args[0]) : null;
      case 'CREATEDBEFORE':
      case 'CREATED_BEFORE':
        return _createTimeFilter(
          args,
          TimeFilterType.olderThan,
          TimeFilterField.created,
        );
      case 'CREATEDAFTER':
      case 'CREATED_AFTER':
        return _createTimeFilter(
          args,
          TimeFilterType.newerThan,
          TimeFilterField.created,
        );
      case 'CREATEDON':
      case 'CREATED_ON':
        return _createTimeFilter(
          args,
          TimeFilterType.between,
          TimeFilterField.created,
          isSingleDay: true,
        );
      case 'CREATEDBETWEEN':
      case 'CREATED_BETWEEN':
        return _createTimeFilter(
          args,
          TimeFilterType.between,
          TimeFilterField.created,
        );
      case 'UPDATEDBEFORE':
      case 'UPDATED_BEFORE':
      case 'BEFORE':
        return _createTimeFilter(
          args,
          TimeFilterType.olderThan,
          TimeFilterField.updated,
        );
      case 'UPDATEDAFTER':
      case 'UPDATED_AFTER':
      case 'AFTER':
        return _createTimeFilter(
          args,
          TimeFilterType.newerThan,
          TimeFilterField.updated,
        );
      case 'UPDATEDON':
      case 'UPDATED_ON':
      case 'ON':
        return _createTimeFilter(
          args,
          TimeFilterType.between,
          TimeFilterField.updated,
          isSingleDay: true,
        );
      case 'UPDATEDBETWEEN':
      case 'UPDATED_BETWEEN':
      case 'BETWEEN':
        return _createTimeFilter(
          args,
          TimeFilterType.between,
          TimeFilterField.updated,
        );
      case 'CREATEDIN':
      case 'CREATED_IN':
        return _createTimeFilter(
          args,
          TimeFilterType.inRange,
          TimeFilterField.created,
        );
      case 'UPDATEDIN':
      case 'UPDATED_IN':
        return _createTimeFilter(
          args,
          TimeFilterType.inRange,
          TimeFilterField.updated,
        );
      case 'TIME':
        if (args.isEmpty) return null;
        final parts = args[0].split(' ');

        TimeFilterField field = TimeFilterField.updated;
        int currentPart = 0;
        try {
          field = TimeFilterField.values.byName(parts[currentPart]);
          currentPart++;
        } catch (_) {
          // It's the old format, which doesn't have a field
        }

        if (parts.length < currentPart + 2) return null;

        final type = TimeFilterType.values.byName(parts[currentPart++]);
        final remaining = parts.sublist(currentPart).join(' ');

        // New format: range string (e.g., "last 5 days")
        if (remaining.startsWith('last')) {
          return TimeFilterElement(
            TimeFilter(type: type, range: remaining, field: field),
          );
        }

        // Old format: value + unit (e.g., "5 days") or specific date
        final date = TimeParser.parse(remaining);
        if (date != null) {
          // This is a specific date from an old filter
          return TimeFilterElement(
            TimeFilter(type: type, specificTime: date, field: field),
          );
        }
        return TimeFilterElement(
          TimeFilter(type: type, range: 'last $remaining', field: field),
        );
      case 'HASHTAG':
        return args.isNotEmpty ? TagElement(args[0], args[0]) : null;
      default:
        return null;
    }
  }

  TimeFilterElement? _createTimeFilter(
    List<String> args,
    TimeFilterType type,
    TimeFilterField field, {
    bool isSingleDay = false,
  }) {
    if (args.isEmpty) return null;

    if (type == TimeFilterType.inRange) {
      final rangeStr = args[0];
      final range = TimeParser.parseRange(rangeStr);
      if (range == null) return null;
      return TimeFilterElement(
        TimeFilter(
          type: type,
          specificTime: range.start,
          specificTimeEnd: range.end,
          range: rangeStr,
          field: field,
        ),
      );
    }

    if (type == TimeFilterType.between) {
      if (isSingleDay) {
        final date = TimeParser.parse(args[0]);
        if (date == null) return null;
        final start = DateTime(date.year, date.month, date.day);
        final end = start.add(const Duration(days: 1));
        return TimeFilterElement(
          TimeFilter(
            type: type,
            specificTime: start,
            specificTimeEnd: end,
            field: field,
          ),
        );
      }
      final parts = args[0].split(',');
      if (parts.length < 2) return null;
      final start = TimeParser.parse(parts[0].trim());
      final end = TimeParser.parse(parts[1].trim());
      if (start == null || end == null) return null;
      return TimeFilterElement(
        TimeFilter(
          type: type,
          specificTime: start,
          specificTimeEnd: end,
          field: field,
        ),
      );
    } else {
      final date = TimeParser.parse(args[0]);
      if (date == null) return null;
      return TimeFilterElement(
        TimeFilter(type: type, specificTime: date, field: field),
      );
    }
  }
}
