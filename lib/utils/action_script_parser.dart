import 'package:duration/duration.dart';
import '../models/bulk_action.dart';
import '../models/filter_element.dart';

class ActionScriptParser {
  static BulkJobConfig parse(String script, FilterElement? filterTree) {
    final lines = script.split('\n');
    final actions = <BulkActionStep>[];
    int parallelQueries = 1;
    Duration waitBetween = const Duration(seconds: 2);
    int? limit;
    int offset = 0;
    bool randomize = false;
    bool stopOnError = false;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }

      // Remove optional trailing semicolon
      if (line.endsWith(';')) {
        line = line.substring(0, line.length - 1).trim();
      }

      if (line.startsWith('@')) {
        final parts = line.substring(1).split(RegExp(r'\s+'));
        final directive = parts[0].toLowerCase();
        final value = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _parseDirective(
            directive,
            value,
            (v) => waitBetween = v,
            (v) => parallelQueries = v,
            (v) => limit = v,
            (v) => offset = v,
            (v) => randomize = v,
            (v) => stopOnError = v);
      } else {

        // Handle "SET Key = Value" or Action or Comment
        // Strip inline comments if simple
        var content = line;
        if (content.contains('//')) {
          content = content.substring(0, content.indexOf('//'));
        }
        content = content.trim();

        if (content.isEmpty) continue;

        if (content.toUpperCase().startsWith('SET ')) {
          content = content.substring(4).trim();
          // Remove optional trailing semicolon again after stripping comment
          if (content.endsWith(';')) {
            content = content.substring(0, content.length - 1).trim();
          }

          final equalsIndex = content.indexOf('=');
        if (equalsIndex != -1) {
          final key = content.substring(0, equalsIndex).trim().toLowerCase();
          var val = content.substring(equalsIndex + 1).trim();
          // Remove quotes if present
          if (val.startsWith('"') && val.endsWith('"')) {
            val = val.substring(1, val.length - 1);
          }

          _parseDirective(
              key,
              val,
              (v) => waitBetween = v,
              (v) => parallelQueries = v,
              (v) => limit = v,
              (v) => offset = v,
              (v) => randomize = v,
              (v) => stopOnError = v);
        }
      } else {
        final parts = line.split(RegExp(r'\s+'));
        final actionName = parts[0];
        final message =
            parts.length > 1 ? parts.sublist(1).join(' ').trim() : null;

        final actionType = BulkActionType.values.firstWhere(
          (e) => e.name == actionName,
          orElse: () => throw FormatException('Unknown action: $actionName'),
        );

        String? extractedMessage;
        if (message != null) {
          if (message.startsWith('"') && message.endsWith('"')) {
            extractedMessage = message.substring(1, message.length - 1);
          } else {
            extractedMessage = message;
          }
        }

        actions.add(BulkActionStep(
          type: actionType,
          message: extractedMessage,
        ));
      }
      }
    }
    return BulkJobConfig(
      targetType: BulkTargetType.filtered,
      filterTree: filterTree,
      sorts: [], // Sorts are handled by the filter expression
      actions: actions,
      parallelQueries: parallelQueries,
      waitBetween: waitBetween,
      limit: limit,
      offset: offset,
      randomize: randomize,
      stopOnError: stopOnError,
    );
  }

  static void _parseDirective(
    String key,
    String value,
    Function(Duration) setWait,
    Function(int) setParallel,
    Function(int?) setLimit,
    Function(int) setOffset,
    Function(bool) setRandomize,
    Function(bool) setStopOnError,
  ) {
    switch (key.toLowerCase()) {
      case 'wait':
      case 'waitbetween':
        final d = _tryParseDuration(value);
        if (d != null) setWait(d);
        break;
      case 'parallel':
      case 'parallelqueries':
        final i = int.tryParse(value);
        if (i != null) setParallel(i);
        break;
      case 'limit':
        final l = int.tryParse(value);
        setLimit(l);
        break;
      case 'offset':
        final o = int.tryParse(value);
        if (o != null) setOffset(o);
        break;
      case 'randomize':
        setRandomize(value.toLowerCase() == 'true');
        break;
      case 'stoponerror':
        setStopOnError(value.toLowerCase() == 'true');
        break;
    }
  }

  static Duration? _tryParseDuration(String input) {
    try {
      return parseDuration(input);
    } catch (e) {
      return null;
    }
  }
}

