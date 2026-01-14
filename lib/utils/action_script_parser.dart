import 'package:duration/duration.dart';
import '../models/bulk_action.dart';
import '../models/enums.dart';
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
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      if (line.startsWith('@')) {
        final parts = line.substring(1).split(RegExp(r'\s+'));
        final directive = parts[0].toLowerCase();
        final value = parts.length > 1 ? parts.sublist(1).join(' ') : '';

        switch (directive) {
          case 'wait':
            waitBetween = _tryParseDuration(value) ?? waitBetween;
            break;
          case 'parallel':
            parallelQueries = int.tryParse(value) ?? parallelQueries;
            break;
          case 'limit':
            limit = int.tryParse(value);
            break;
          case 'offset':
            offset = int.tryParse(value) ?? offset;
            break;
          case 'randomize':
            randomize = value.toLowerCase() == 'true';
            break;
          case 'stoponerror':
            stopOnError = value.toLowerCase() == 'true';
            break;
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

  static Duration? _tryParseDuration(String input) {
    try {
      return parseDuration(input);
    } catch (e) {
      return null;
    }
  }
}
