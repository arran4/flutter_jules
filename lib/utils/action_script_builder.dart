import '../../models/bulk_action.dart';

String buildActionScript({
  required List<BulkActionStep> actions,
  required int parallelQueries,
  required Duration waitBetween,
  required int? limit,
  required int offset,
  required bool randomize,
  required bool stopOnError,
}) {
  final buffer = StringBuffer();

  // Settings
  buffer.writeln('// Execution Settings');
  buffer.writeln('SET ParallelQueries = $parallelQueries;');
  buffer.writeln('SET WaitBetween = "${waitBetween.inSeconds}s";');
  if (limit != null) {
    buffer.writeln('SET Limit = $limit;');
  }
  if (offset > 0) {
    buffer.writeln('SET Offset = $offset;');
  }
  if (randomize) {
    buffer.writeln('SET Randomize = true;');
  }
  if (stopOnError) {
    buffer.writeln('SET StopOnError = true;');
  }
  buffer.writeln();

  // Actions
  buffer.writeln('// Actions to Perform');
  for (final action in actions) {
    buffer.write(action.type.name);
    if (action.type.requiresMessage && action.message != null) {
      buffer.write(' "${action.message}"');
    }
    buffer.writeln(';');
  }

  return buffer.toString();
}
